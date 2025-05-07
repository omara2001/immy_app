import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:immy_app/services/backend_api_service.dart';
import 'package:immy_app/services/stripe_service.dart';
import 'package:immy_app/services/stripe_sync_service.dart';
import 'package:http/http.dart' as http;

class PaymentProcessor {
  static const String apiUrl = 'https://api.stripe.com/v1';
  static String? _publishableKey;
  static bool _initialized = false;
  static final StripeSyncService _syncService = StripeSyncService();

  // Initialize the payment processor
  static Future<void> initialize(String publishableKey) async {
    if (_initialized) return;
    
    _publishableKey = publishableKey;
    
    // Initialize Stripe SDK
    Stripe.publishableKey = publishableKey;
    try {
      await Stripe.instance.applySettings();
      _initialized = true;
      print('PaymentProcessor initialized with publishable key: $publishableKey');
    } catch (e) {
      print('Error initializing Stripe SDK: $e');
      // We still mark as initialized since we can fall back to API calls
      _initialized = true;
    }
  }
  
  // Mask API key for logging
  static String _maskKey(String key) {
    if (key.length > 8) {
      return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
    }
    return '****';
  }
  
  // Process a payment using Payment Sheet
  static Future<Map<String, dynamic>> processPayment({
    required int userId,
    required int serialId,
    required double amount,
    required String currency,
    required String customerEmail,
    String? customerName,
  }) async {
    if (!_initialized) {
      throw Exception('Payment processor not initialized');
    }
    
    try {
      print('Processing payment for user $userId ($customerEmail) - amount: $amount $currency');
      
      // 1. Create/get customer ID in Stripe
      String customerId = await _getOrCreateCustomerId(userId, customerEmail, customerName);
      print('Using customer ID: $customerId for email: $customerEmail');
      
      // 2. Create a payment intent on the server
      final paymentIntentResult = await _createPaymentIntent(
        amount: (amount * 100).round().toString(), // Convert to cents/smallest unit
        currency: currency.toLowerCase(),
        customerId: customerId,
        metadata: {
          'user_id': userId.toString(),
          'serial_id': serialId.toString(),
          'customer_email': customerEmail,
        },
      );
      
      final clientSecret = paymentIntentResult['client_secret'];
      if (clientSecret == null) {
        throw Exception('Failed to create payment intent - client secret is null');
      }
      
      print('Payment intent created with ID: ${paymentIntentResult['id']}');

      // 3. Initialize the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Immy App',
          customerId: customerId,
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.purple,
            ),
          ),
        ),
      );

      // 4. Present the payment sheet to the user
      await Stripe.instance.presentPaymentSheet();
      
      // 5. Payment was successful if we get here (exceptions are thrown if payment fails)
      // Sync with StripeService to ensure database has the latest payment data
      await _syncService.syncUserWithStripe(userId, customerId);
      
      // Create payment record in our database
      final payment = await BackendApiService.createPayment(
        userId,
        serialId,
        amount,
        currency,
        stripePaymentId: paymentIntentResult['id'],
        stripePaymentMethodId: paymentIntentResult['payment_method'],
      );
      
      // 6. Create subscription record
      final endDate = DateTime.now().add(const Duration(days: 30));
      final subscription = await BackendApiService.createSubscription(
        userId,
        serialId,
        endDate,
        stripeSubscriptionId: paymentIntentResult['id'],
        stripePriceId: 'price_standard', // Can be made dynamic in future
      );
      
      return {
        'success': true,
        'payment': payment,
        'subscription': subscription,
        'paymentIntent': paymentIntentResult,
      };
    } catch (e) {
      print('Payment processing error: $e');
      
      if (e is StripeException) {
        return {
          'success': false,
          'error': e.error.localizedMessage,
          'code': e.error.code,
        };
      }
      
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Sync user's payments with Stripe
  static Future<Map<String, int>> syncWithStripe(int userId) async {
    try {
      // Get customer ID
      final customerId = await StripeService.getOrCreateCustomerId(userId);
      
      // Use StripeSyncService to sync data
      return await _syncService.syncUserWithStripe(userId, customerId);
    } catch (e) {
      print('Error syncing with Stripe: $e');
      return {'payments': 0, 'subscriptions': 0};
    }
  }
  
  // Get all payment methods for a customer
  static Future<List<Map<String, dynamic>>> getPaymentMethods(String customerId) async {
    try {
      return await StripeService.getCustomerPaymentMethods(customerId: customerId);
    } catch (e) {
      print('Error getting payment methods: $e');
      return [];
    }
  }
  
  // Create a setup intent for adding a payment method without charging
  static Future<Map<String, dynamic>> createSetupIntent(int userId) async {
    try {
      // Get customer ID
      final customerId = await StripeService.getOrCreateCustomerId(userId);
      
      return await StripeService.createSetupIntent(
        userId: userId,
        customerId: customerId,
      );
    } catch (e) {
      print('Error creating setup intent: $e');
      return {
        'client_secret': null,
        'setup_intent_id': null,
        'error': e.toString(),
      };
    }
  }
  
  // Update a payment method for future use
  static Future<bool> updatePaymentMethod({
    required int userId, 
    required String customerEmail,
    String? customerName,
  }) async {
    try {
      // 1. Get or create customer ID
      final customerId = await _getOrCreateCustomerId(userId, customerEmail, customerName);
      
      // 2. Create a setup intent
      final setupIntent = await createSetupIntent(userId);
      
      if (setupIntent['client_secret'] == null) {
        throw Exception('Failed to create setup intent');
      }
      
      // 3. Initialize payment sheet for setup
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupIntent['client_secret'],
          merchantDisplayName: 'Immy App',
          customerId: customerId,
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.purple,
            ),
          ),
        ),
      );
      
      // 4. Present the payment sheet for setup
      await Stripe.instance.presentPaymentSheet();
      
      // 5. Success if we get to this point
      return true;
    } catch (e) {
      print('Error updating payment method: $e');
      return false;
    }
  }
  
  // Cancel a subscription
  static Future<bool> cancelSubscription(int userId, String subscriptionId) async {
    try {
      print('Attempting to cancel subscription: $subscriptionId for user: $userId');
      
      if (subscriptionId.isEmpty) {
        print('Cannot cancel subscription with empty ID');
        throw Exception('Subscription ID is empty');
      }
      
      // Check if this is a regular payment intent ID being used as a subscription (our app does this)
      final bool isPaymentIntent = subscriptionId.startsWith('pi_');
      
      // Track if this is a mock/test subscription to handle differently
      final bool isMockSubscription = 
        subscriptionId.startsWith('sub_test') || 
        subscriptionId.startsWith('sub_mock') ||
        subscriptionId.startsWith('sub_fallback') ||
        subscriptionId.startsWith('sub_renewal');
      
      // For real subscriptions, try to cancel in Stripe
      if (!isMockSubscription && !isPaymentIntent) {
        try {
          print('Cancelling real subscription in Stripe: $subscriptionId');
          await StripeService.cancelSubscription(subscriptionId: subscriptionId);
          print('Successfully cancelled in Stripe');
        } catch (stripeError) {
          print('Error cancelling subscription in Stripe: $stripeError');
          // Continue anyway to update our database - the subscription might not exist in Stripe
          // but we still want to mark it as cancelled in our system
        }
      } else if (isPaymentIntent) {
        print('This is a payment intent ID, not a subscription ID. Marking as cancelled in database only.');
      } else {
        print('This is a mock subscription, skipping Stripe API call');
      }
      
      // Always update the status in our database
      print('Updating subscription status to cancelled in database');
      await BackendApiService.executeQuery(
        'UPDATE Subscriptions SET status = ? WHERE stripe_subscription_id = ?',
        ['cancelled', subscriptionId]
      );
      
      // Verify the update was successful
      final updatedSubs = await BackendApiService.executeQuery(
        'SELECT * FROM Subscriptions WHERE stripe_subscription_id = ?',
        [subscriptionId]
      );
      
      if (updatedSubs.isEmpty) {
        print('Warning: Subscription not found in database after update: $subscriptionId');
      } else {
        final status = updatedSubs.first['status'];
        print('Subscription status after update: $status');
      }
      
      return true;
    } catch (e) {
      print('Error cancelling subscription: $e');
      return false;
    }
  }
  
  // Get payment history for a customer
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String customerId) async {
    try {
      // Get payment history from Stripe
      final stripePayments = await StripeService.getCustomerPayments(customerId);
      
      // Transform to a consistent format
      return stripePayments.map((payment) {
        return {
          'id': payment['id'],
          'amount': payment['amount'] / 100.0, // Convert from cents to currency
          'currency': payment['currency'],
          'status': payment['status'],
          'created_at': DateTime.fromMillisecondsSinceEpoch(payment['created'] * 1000).toIso8601String(),
        };
      }).toList();
    } catch (e) {
      print('Error getting payment history: $e');
      
      // Return empty list on error
      return [];
    }
  }
  
  // Verify that a user has an active subscription
  static Future<bool> verifyActiveSubscription(int userId) async {
    try {
      // Check for active subscriptions in the database
      final subscriptions = await BackendApiService.executeQuery(
        'SELECT * FROM Subscriptions WHERE user_id = ? AND status = ? AND end_date > NOW()',
        [userId, 'active']
      );
      
      return subscriptions.isNotEmpty;
    } catch (e) {
      print('Error verifying subscription: $e');
      return false;
    }
  }
  
  // Get or create a Stripe customer
  static Future<String> _getOrCreateCustomerId(int userId, String email, String? name) async {
    try {
      print('Getting/creating customer ID for user $userId with email $email');
      
      if (email.isEmpty) {
        throw Exception('Customer email cannot be empty');
      }
      
      // First try to get from database
      final userRows = await BackendApiService.executeQuery(
        'SELECT stripe_customer_id FROM Users WHERE id = ?',
        [userId]
      );
      
      if (userRows.isNotEmpty && userRows.first['stripe_customer_id'] != null) {
        final existingId = userRows.first['stripe_customer_id'];
        if (existingId.toString().isNotEmpty) {
          print('Found existing Stripe customer ID in database: $existingId');
          return existingId;
        }
      }
      
      // Look up customer in Stripe by email
      final customerId = await StripeService.getOrCreateCustomerId(userId);
      print('Got customer ID from Stripe: $customerId');
      
      return customerId;
    } catch (e) {
      print('Error getting/creating customer: $e');
      rethrow;
    }
  }
  
  // Create a payment intent
  static Future<Map<String, dynamic>> _createPaymentIntent({
    required String amount,
    required String currency,
    required String customerId,
    Map<String, String>? metadata,
  }) async {
    try {
      // Delegate to StripeService
      return await StripeService.createPaymentIntent(
        amount: amount,
        currency: currency,
        customerId: customerId,
        metadata: metadata,
      );
    } catch (e) {
      print('Error creating payment intent: $e');
      rethrow;
    }
  }
  
  // Retrieve a specific payment
  static Future<Map<String, dynamic>?> retrievePayment(String paymentIntentId) async {
    try {
      return await StripeService.retrievePaymentIntent(paymentIntentId);
    } catch (e) {
      print('Error retrieving payment: $e');
      return null;
    }
  }
} 