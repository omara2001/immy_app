import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_api_service.dart';
import 'stripe_service.dart';

class StripeSyncService {
  // Singleton pattern
  static final StripeSyncService _instance = StripeSyncService._internal();
  factory StripeSyncService() => _instance;
  StripeSyncService._internal();

  // Flag to prevent multiple syncs running simultaneously
  bool _isSyncing = false;

  // Sync payments and subscriptions from Stripe to local database
  Future<Map<String, int>> syncUserWithStripe(int userId, String customerId) async {
    if (_isSyncing) {
      print('Sync already in progress, skipping');
      return {'payments': 0, 'subscriptions': 0};
    }

    _isSyncing = true;
    int syncedPayments = 0;
    int syncedSubscriptions = 0;

    try {
      print('Starting Stripe sync for user $userId with customer ID $customerId');
      
      // First, ensure we have a valid serial number for this user
      int serialId = await _getOrCreateSerialNumber(userId);
      
      // 1. Sync payments from Stripe
      final stripePayments = await StripeService.getCustomerPayments(customerId);
      print('Found ${stripePayments.length} payments in Stripe');
      
      for (final payment in stripePayments) {
        if (payment['status'] == 'succeeded') {
          final paymentId = payment['id'];
          final amount = payment['amount'] / 100.0;
          final currency = payment['currency'];
          
          // Check if this payment exists in our database
          final existingPayments = await BackendApiService.executeQuery(
            'SELECT * FROM Payments WHERE stripe_payment_id = ?',
            [paymentId]
          );
          
          if (existingPayments.isEmpty) {
            try {
              // Create payment record if it doesn't exist
              await BackendApiService.createPayment(
                userId,
                serialId,
                amount,
                currency,
                stripePaymentId: paymentId
              );
              
              print('Created new payment record for payment: $paymentId');
              syncedPayments++;
              
              // Check if there's an active subscription for this payment
              final subscriptions = await BackendApiService.executeQuery(
                'SELECT * FROM Subscriptions WHERE user_id = ? AND stripe_subscription_id = ?',
                [userId, paymentId]
              );
              
              if (subscriptions.isEmpty) {
                // Create subscription if it doesn't exist
                final endDate = DateTime.now().add(const Duration(days: 30));
                await _createSubscriptionSafely(
                  userId, 
                  serialId, 
                  endDate,
                  paymentId,
                  'price_standard'
                );
                
                print('Created new subscription record for payment: $paymentId');
                syncedSubscriptions++;
              }
            } catch (e) {
              print('Error creating payment/subscription records: $e');
            }
          }
        }
      }
      
      // 2. Sync subscriptions directly from Stripe
      try {
        final response = await http.get(
          Uri.parse('${StripeService.baseUrl}/subscriptions?customer=$customerId&limit=10'),
          headers: StripeService.headers,
        );
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          final subscriptions = List<Map<String, dynamic>>.from(result['data']);
          
          print('Found ${subscriptions.length} subscriptions in Stripe');
          
          for (final subscription in subscriptions) {
            if (subscription['status'] == 'active' || subscription['status'] == 'trialing') {
              final subscriptionId = subscription['id'];
              
              // Check if this subscription exists in our database
              final existingSubscriptions = await BackendApiService.executeQuery(
                'SELECT * FROM Subscriptions WHERE stripe_subscription_id = ?',
                [subscriptionId]
              );
              
              if (existingSubscriptions.isEmpty) {
                // Extract price ID
                String priceId = '';
                if (subscription['items']['data'].isNotEmpty) {
                  priceId = subscription['items']['data'][0]['price']['id'];
                }
                
                // Create subscription record
                final endDate = DateTime.fromMillisecondsSinceEpoch(subscription['current_period_end'] * 1000);
                await _createSubscriptionSafely(
                  userId, 
                  serialId, 
                  endDate,
                  subscriptionId,
                  priceId
                );
                
                print('Created new subscription record for subscription: $subscriptionId');
                syncedSubscriptions++;
              } else {
                // Update existing subscription
                final endDate = DateTime.fromMillisecondsSinceEpoch(subscription['current_period_end'] * 1000);
                await BackendApiService.executeQuery(
                  'UPDATE Subscriptions SET status = ?, end_date = ? WHERE stripe_subscription_id = ?',
                  [subscription['status'], endDate.toIso8601String(), subscriptionId]
                );
                
                print('Updated existing subscription: $subscriptionId');
              }
            }
          }
        }
      } catch (e) {
        print('Error syncing subscriptions: $e');
      }
      
      print('Stripe sync completed: synced $syncedPayments payments and $syncedSubscriptions subscriptions');
      return {
        'payments': syncedPayments,
        'subscriptions': syncedSubscriptions
      };
    } catch (e) {
      print('Error during Stripe sync: $e');
      return {'payments': 0, 'subscriptions': 0};
    } finally {
      _isSyncing = false;
    }
  }
  
  // Helper method to get or create a valid serial number for a user
  Future<int> _getOrCreateSerialNumber(int userId) async {
    try {
      // Try to get existing serial numbers
      final serials = await BackendApiService.executeQuery(
        'SELECT id FROM SerialNumbers WHERE user_id = ? LIMIT 1',
        [userId]
      );
      
      if (serials.isNotEmpty) {
        return serials.first['id'];
      }
      
      // No serial number found, create one
      print('No serial number found for user $userId, creating one...');
      final serialNumber = 'SN-${userId}-${DateTime.now().millisecondsSinceEpoch}';
      
      final result = await BackendApiService.executeInsert(
        'INSERT INTO SerialNumbers (user_id, serial, created_at) VALUES (?, ?, NOW())',
        [userId, serialNumber]
      );
      
      if (result > 0) {
        print('Created new serial number: $serialNumber with ID: $result');
        return result;
      } else {
        throw Exception('Failed to create serial number');
      }
    } catch (e) {
      print('Error getting or creating serial number: $e');
      throw Exception('Failed to get or create serial number: $e');
    }
  }
  
  // Helper method to safely create a subscription with proper error handling
  Future<int> _createSubscriptionSafely(
    int userId, 
    int serialId, 
    DateTime endDate, 
    String subscriptionId, 
    String priceId
  ) async {
    try {
      // Verify the serial ID exists
      final serials = await BackendApiService.executeQuery(
        'SELECT id FROM SerialNumbers WHERE id = ?',
        [serialId]
      );
      
      if (serials.isEmpty) {
        print('Serial ID $serialId not found, getting a valid one...');
        serialId = await _getOrCreateSerialNumber(userId);
      }
      
      // Convert DateTime to String before passing to SQL
      final endDateString = endDate.toIso8601String();
      
      // Create the subscription
      final result = await BackendApiService.executeInsert(
        'INSERT INTO Subscriptions (user_id, serial_id, status, start_date, end_date, stripe_subscription_id, stripe_price_id) VALUES (?, ?, ?, NOW(), ?, ?, ?)',
        [userId, serialId, 'active', endDateString, subscriptionId, priceId]
      );
      
      print('Subscription created with ID: $result');
      return result;
    } catch (e) {
      print('Failed to create subscription record: $e');
      
      // Fallback: Try direct insert with minimal fields
      try {
        print('Failed to create subscription record, using fallback...');
        // Convert DateTime to String before passing to SQL
        final endDateString = endDate.toIso8601String();
        
        final result = await BackendApiService.executeInsert(
          'INSERT INTO Subscriptions (user_id, serial_id, status, start_date, end_date, stripe_subscription_id, stripe_price_id) VALUES (?, ?, ?, NOW(), ?, ?, ?)',
          [userId, serialId, 'active', endDateString, subscriptionId, priceId]
        );
        
        print('Subscription created with ID: $result');
        return result;
      } catch (fallbackError) {
        print('Fallback subscription creation also failed: $fallbackError');
        return -1;
      }
    }
  }
  
  // Check if a user has an active subscription
  Future<bool> checkUserSubscriptionStatus(int userId) async {
    try {
      // Check for active subscriptions in the database
      final subscriptions = await BackendApiService.executeQuery(
        'SELECT * FROM Subscriptions WHERE user_id = ? AND status = ? AND end_date > NOW()',
        [userId, 'active']
      );
      
      return subscriptions.isNotEmpty;
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }
  
  // Verify a specific payment and create subscription if needed
  Future<bool> verifyAndProcessPayment(String paymentIntentId, int userId) async {
    try {
      // Get payment details from Stripe
      final paymentIntent = await StripeService.retrievePaymentIntent(paymentIntentId);
      
      if (paymentIntent['status'] == 'succeeded') {
        // Get or create a valid serial number
        final serialId = await _getOrCreateSerialNumber(userId);
        
        // Check if payment exists in database
        final existingPayments = await BackendApiService.executeQuery(
          'SELECT * FROM Payments WHERE stripe_payment_id = ?',
          [paymentIntentId]
        );
        
        if (existingPayments.isEmpty) {
          // Create payment record
          final amount = paymentIntent['amount'] / 100.0;
          final currency = paymentIntent['currency'];
          
          await BackendApiService.createPayment(
            userId,
            serialId,
            amount,
            currency,
            stripePaymentId: paymentIntentId
          );
        }
        
        // Check if subscription exists
        final existingSubscriptions = await BackendApiService.executeQuery(
          'SELECT * FROM Subscriptions WHERE user_id = ? AND stripe_subscription_id = ?',
          [userId, paymentIntentId]
        );
        
        if (existingSubscriptions.isEmpty) {
          // Create subscription
          final endDate = DateTime.now().add(const Duration(days: 30));
          await _createSubscriptionSafely(
            userId,
            serialId,
            endDate,
            paymentIntentId,
            'price_standard'
          );
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }
}
