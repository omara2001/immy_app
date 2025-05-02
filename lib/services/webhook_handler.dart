import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/backend_api_service.dart';
import '../services/stripe_service.dart';

class WebhookHandler {
  static const String _endpointSecret = 'whsec_1d3bcb16bbc5da4b89b7d6f31da988f14c5c0d7b2f3cb4586d5f31c2c13f41b6'; // Webhook signing secret
  // Handle Stripe webhook events
  static Future<Map<String, dynamic>> handleWebhook(
    String payload,
    String signature,
  ) async {
    try {
      // Verify webhook signature
      if (!kIsWeb && _endpointSecret.isNotEmpty) {
        _verifySignature(payload, signature);
      }
      
      // Parse event
      final event = jsonDecode(payload);
      final eventType = event['type'];
      
      print('Processing webhook: $eventType');
      
      // Handle different event types
      switch (eventType) {
        case 'payment_intent.succeeded':
          await _handlePaymentIntentSucceeded(event['data']['object']);
          break;
        case 'payment_intent.payment_failed':
          await _handlePaymentIntentFailed(event['data']['object']);
          break;
        case 'customer.subscription.created':
          await _handleSubscriptionCreated(event['data']['object']);
          break;
        case 'customer.subscription.updated':
          await _handleSubscriptionUpdated(event['data']['object']);
          break;
        case 'customer.subscription.deleted':
          await _handleSubscriptionDeleted(event['data']['object']);
          break;
        case 'invoice.payment_succeeded':
          await _handleInvoicePaymentSucceeded(event['data']['object']);
          break;
        case 'invoice.payment_failed':
          await _handleInvoicePaymentFailed(event['data']['object']);
          break;
      }
      
      return {'received': true};
    } catch (e) {
      print('Error handling webhook: $e');
      throw Exception('Webhook error: $e');
    }
  }
  
  // Verify webhook signature
  static void _verifySignature(String payload, String signature) {
    try {
      final List<String> signatureParts = signature.split(',');
      String timestampPart = '';
      String signaturePart = '';
      
      for (final part in signatureParts) {
        if (part.startsWith('t=')) {
          timestampPart = part.substring(2);
        } else if (part.startsWith('v1=')) {
          signaturePart = part.substring(3);
        }
      }
      
      if (timestampPart.isEmpty || signaturePart.isEmpty) {
        throw Exception('Invalid signature format');
      }
      
      final signedPayload = '$timestampPart.$payload';
      final hmac = Hmac(sha256, utf8.encode(_endpointSecret));
      final digest = hmac.convert(utf8.encode(signedPayload));
      final computedSignature = digest.toString();
      
      if (computedSignature != signaturePart) {
        throw Exception('Signature verification failed');
      }
    } catch (e) {
      print('Signature verification failed: $e');
      throw Exception('Webhook signature verification failed: $e');
    }
  }
  
  // Handle payment_intent.succeeded event
  static Future<void> _handlePaymentIntentSucceeded(Map<String, dynamic> paymentIntent) async {
    try {
      final metadata = paymentIntent['metadata'] ?? {};
      final userId = int.tryParse(metadata['user_id']?.toString() ?? '');
      final serialId = int.tryParse(metadata['serial_id']?.toString() ?? '');
      
      if (userId == null || serialId == null) {
        print('Missing user_id or serial_id in payment intent metadata, trying to find user from payment method');
        
        // Try to find the user from the payment method's customer
        String? customerId;
        if (paymentIntent.containsKey('customer')) {
          customerId = paymentIntent['customer']?.toString();
        }
        
        if (customerId != null) {
          final users = await BackendApiService.executeQuery(
            'SELECT id FROM Users WHERE stripe_customer_id = ?',
            [customerId]
          );
          
          if (users.isNotEmpty) {
            final foundUserId = users.first['id'];
            
            // Get the first serial number for this user
            final serials = await BackendApiService.executeQuery(
              'SELECT id FROM SerialNumbers WHERE user_id = ? LIMIT 1',
              [foundUserId]
            );
            
            if (serials.isNotEmpty) {
              // Use the found user and serial
              final foundSerialId = serials.first['id'];
              
              // Update payment status in database
              await _updatePaymentAndSubscription(
                foundUserId, 
                foundSerialId, 
                paymentIntent
              );
              return;
            }
          }
        }
        
        print('Could not determine user and serial from payment intent');
        return;
      }
      
      // Update payment and subscription with the metadata user/serial
      await _updatePaymentAndSubscription(userId, serialId, paymentIntent);
    } catch (e) {
      print('Error handling payment_intent.succeeded: $e');
    }
  }
  
  // Helper method to update payment and subscription
  static Future<void> _updatePaymentAndSubscription(
    int userId, 
    int serialId, 
    Map<String, dynamic> paymentIntent
  ) async {
    // Update payment status in database
    final payments = await BackendApiService.executeQuery(
      'SELECT * FROM Payments WHERE stripe_payment_id = ?',
      [paymentIntent['id']]
    );
    
    if (payments.isNotEmpty) {
      await BackendApiService.executeQuery(
        'UPDATE Payments SET payment_status = ? WHERE stripe_payment_id = ?',
        ['completed', paymentIntent['id']]
      );
    } else {
      // Create payment record if it doesn't exist
      final amount = paymentIntent['amount'] / 100.0;
      final currency = paymentIntent['currency'];
      String? paymentMethodId;
      
      // Safely extract payment method ID
      if (paymentIntent.containsKey('payment_method')) {
        paymentMethodId = paymentIntent['payment_method']?.toString();
      }
      
      await BackendApiService.createPayment(
        userId, 
        serialId, 
        amount, 
        currency, 
        stripePaymentId: paymentIntent['id'],
        stripePaymentMethodId: paymentMethodId
      );
    }
    
    // Create subscription if it doesn't exist
    final subscriptions = await BackendApiService.executeQuery(
      'SELECT * FROM Subscriptions WHERE user_id = ? AND serial_id = ? AND status = ?',
      [userId, serialId, 'active']
    );
    
    if (subscriptions.isEmpty) {
      final endDate = DateTime.now().add(const Duration(days: 30));
      await BackendApiService.createSubscription(
        userId, 
        serialId, 
        endDate,
        stripeSubscriptionId: paymentIntent['id'],
        stripePriceId: ''
      );
    }
  }
  
  // Handle payment_intent.payment_failed event
  static Future<void> _handlePaymentIntentFailed(Map<String, dynamic> paymentIntent) async {
    try {
      // Update payment status in database
      await BackendApiService.executeQuery(
        'UPDATE Payments SET payment_status = ? WHERE stripe_payment_id = ?',
        ['failed', paymentIntent['id']]
      );
    } catch (e) {
      print('Error handling payment_intent.payment_failed: $e');
    }
  }
  
  // Handle customer.subscription.created event
  static Future<void> _handleSubscriptionCreated(Map<String, dynamic> subscription) async {
    try {
      final customerId = subscription['customer'];
      
      // Find user with this Stripe customer ID
      final users = await BackendApiService.executeQuery(
        'SELECT * FROM Users WHERE stripe_customer_id = ?',
        [customerId]
      );
      
      if (users.isEmpty) {
        print('No user found with Stripe customer ID: $customerId');
        return;
      }
      
      final userId = users.first['id'];
      
      // Get user's serial numbers
      final serials = await BackendApiService.executeQuery(
        'SELECT * FROM SerialNumbers WHERE user_id = ?',
        [userId]
      );
      
      if (serials.isEmpty) {
        print('No serial numbers found for user ID: $userId');
        return;
      }
      
      // Create subscription for each serial number
      final endDate = DateTime.fromMillisecondsSinceEpoch(
        subscription['current_period_end'] * 1000
      );
      
      // Extract price ID safely
      String? priceId;
      try {
        final items = subscription['items'] as Map<String, dynamic>?;
        if (items != null && items.containsKey('data')) {
          final dataList = items['data'] as List?;
          if (dataList != null && dataList.isNotEmpty) {
            final firstItem = dataList[0] as Map<String, dynamic>?;
            if (firstItem != null && firstItem.containsKey('price')) {
              final price = firstItem['price'] as Map<String, dynamic>?;
              priceId = price?['id'] as String?;
            }
          }
        }
      } catch (e) {
        print('Error extracting price ID: $e');
      }
      
      for (final serial in serials) {
        await BackendApiService.createSubscription(
          userId, 
          serial['id'], 
          endDate,
          stripeSubscriptionId: subscription['id'],
          stripePriceId: priceId
        );
      }
    } catch (e) {
      print('Error handling customer.subscription.created: $e');
    }
  }
  
  // Handle customer.subscription.updated event
  static Future<void> _handleSubscriptionUpdated(Map<String, dynamic> subscription) async {
    try {
      final status = subscription['status'];
      
      // Update subscription status in database
      await BackendApiService.executeQuery(
        'UPDATE Subscriptions SET status = ? WHERE stripe_subscription_id = ?',
        [status, subscription['id']]
      );
      
      // If subscription is active, update end date
      if (status == 'active') {
        final endDate = DateTime.fromMillisecondsSinceEpoch(
          subscription['current_period_end'] * 1000
        );
        
        await BackendApiService.executeQuery(
          'UPDATE Subscriptions SET end_date = ? WHERE stripe_subscription_id = ?',
          [endDate.toIso8601String(), subscription['id']]
        );
      }
    } catch (e) {
      print('Error handling customer.subscription.updated: $e');
    }
  }
  
  // Handle customer.subscription.deleted event
  static Future<void> _handleSubscriptionDeleted(Map<String, dynamic> subscription) async {
    try {
      // Update subscription status in database
      await BackendApiService.executeQuery(
        'UPDATE Subscriptions SET status = ? WHERE stripe_subscription_id = ?',
        ['canceled', subscription['id']]
      );
    } catch (e) {
      print('Error handling customer.subscription.deleted: $e');
    }
  }
  
  // Handle invoice.payment_succeeded event
  static Future<void> _handleInvoicePaymentSucceeded(Map<String, dynamic> invoice) async {
    try {
      final subscriptionId = invoice['subscription'];
      final customerId = invoice['customer'];
      if (subscriptionId == null) return;
      
      // Get subscription details from Stripe
      final response = await http.get(
        Uri.parse('${StripeService.baseUrl}/subscriptions/$subscriptionId'),
        headers: StripeService.headers,
      );
      
      if (response.statusCode != 200) {
        print('Error fetching subscription: ${response.body}');
        return;
      }
      
      final subscription = jsonDecode(response.body);
      
      final endDate = DateTime.fromMillisecondsSinceEpoch(
        subscription['current_period_end'] * 1000
      );
      
      // Update subscription status and end date in database
      await BackendApiService.executeQuery(
        'UPDATE Subscriptions SET status = ?, end_date = ? WHERE stripe_subscription_id = ?',
        ['active', endDate.toIso8601String(), subscriptionId]
      );

      // Create payment record
      final amount = invoice['amount_paid'] / 100.0;
      final currency = invoice['currency'];
      
      // Get user ID from customer ID
      final users = await BackendApiService.executeQuery(
        'SELECT id FROM Users WHERE stripe_customer_id = ?',
        [customerId]
      );
      
      if (users.isNotEmpty) {
        final userId = users.first['id'];
        await BackendApiService.executeInsert(
          'INSERT INTO Payments (user_id, amount, currency, payment_status, stripe_payment_id) VALUES (?, ?, ?, ?, ?)',
          [userId, amount, currency, 'completed', invoice['payment_intent']]
        );
      }
    } catch (e) {
      print('Error handling invoice.payment_succeeded: $e');
    }
  }
  
  // Handle invoice.payment_failed event
  static Future<void> _handleInvoicePaymentFailed(Map<String, dynamic> invoice) async {
    try {
      final subscriptionId = invoice['subscription'];
      if (subscriptionId == null) return;
      
      // Update subscription status in database
      await BackendApiService.executeQuery(
        'UPDATE Subscriptions SET status = ? WHERE stripe_subscription_id = ?',
        ['past_due', subscriptionId]
      );
    } catch (e) {
      print('Error handling invoice.payment_failed: $e');
    }
  }
}