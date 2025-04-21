import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/backend_api_service.dart';

class StripeService {
  // Stripe API endpoints
  static const String baseUrl = 'https://api.stripe.com/v1';  // Removed underscore
  static const String _paymentIntentUrl = '$baseUrl/payment_intents';
  static const String _customersUrl = '$baseUrl/customers';
  static const String _paymentMethodsUrl = '$baseUrl/payment_methods';
  
  // Stripe API keys
  static String? _secretKey;
  static String? _publishableKey;
  
  // Initialize the Stripe service with API keys
  static void initialize({required String secretKey, required String publishableKey}) {
    _secretKey = secretKey;
    _publishableKey = publishableKey;
  }
  
  // Get the publishable key for client-side operations
  static String? get publishableKey => _publishableKey;
  
  // Headers for Stripe API requests
  static Map<String, String> get headers => {  // Removed underscore
    'Authorization': 'Bearer $_secretKey',
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  
  // Create a Stripe customer
  static Future<Map<String, dynamic>> createCustomer({
    required String email,
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_customersUrl),
        headers: headers,
        body: {
          'email': email,
          if (name != null) 'name': name,
        },
      );
      
      return handleResponse(response);
    } catch (e) {
      print('Error creating Stripe customer: $e');
      throw Exception('Failed to create Stripe customer: $e');
    }
  }
  
  // Create a payment intent
  static Future<Map<String, dynamic>> createPaymentIntent({
    required String amount,
    required String currency,
    String? customerId,
    String? paymentMethodId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'amount': amount,
        'currency': currency,
        'payment_method_types[]': 'card',
      };
      
      if (customerId != null) {
        body['customer'] = customerId;
      }
      
      if (paymentMethodId != null) {
        body['payment_method'] = paymentMethodId;
        body['confirm'] = 'true';
      }
      
      if (metadata != null) {
        metadata.forEach((key, value) {
          body['metadata[$key]'] = value.toString();
        });
      }
      
      final response = await http.post(
        Uri.parse(_paymentIntentUrl),
        headers: headers,
        body: body,
      );
      
      return handleResponse(response);
    } catch (e) {
      print('Error creating payment intent: $e');
      throw Exception('Failed to create payment intent: $e');
    }
  }
  
  // Attach a payment method to a customer
  static Future<Map<String, dynamic>> attachPaymentMethodToCustomer({
    required String paymentMethodId,
    required String customerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_paymentMethodsUrl/$paymentMethodId/attach'),
        headers: headers,
        body: {
          'customer': customerId,
        },
      );
      
      return handleResponse(response);
    } catch (e) {
      print('Error attaching payment method: $e');
      throw Exception('Failed to attach payment method: $e');
    }
  }
  
  // Confirm a payment intent
  static Future<Map<String, dynamic>> confirmPaymentIntent({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_paymentIntentUrl/$paymentIntentId/confirm'),
        headers: headers,
        body: {
          'payment_method': paymentMethodId,
        },
      );
      
      return handleResponse(response);
    } catch (e) {
      print('Error confirming payment intent: $e');
      throw Exception('Failed to confirm payment intent: $e');
    }
  }
  
  // Get customer payment methods
  static Future<List<Map<String, dynamic>>> getCustomerPaymentMethods({
    required String customerId,
    String type = 'card',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_paymentMethodsUrl?customer=$customerId&type=$type'),
        headers: headers,
      );
      
      final result = handleResponse(response);
      return List<Map<String, dynamic>>.from(result['data'] ?? []);
    } catch (e) {
      print('Error getting customer payment methods: $e');
      throw Exception('Failed to get customer payment methods: $e');
    }
  }
  
  // Create a subscription
  static Future<Map<String, dynamic>> createSubscription({
    required String customerId,
    required String priceId,
    String? paymentMethodId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'customer': customerId,
        'items[0][price]': priceId,
      };
      
      if (paymentMethodId != null) {
        body['default_payment_method'] = paymentMethodId;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/subscriptions'),
        headers: headers,
        body: body,
      );
      
      return handleResponse(response);
    } catch (e) {
      print('Error creating subscription: $e');
      throw Exception('Failed to create subscription: $e');
    }
  }
  
  // Cancel a subscription
  static Future<Map<String, dynamic>> cancelSubscription({
    required String subscriptionId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/subscriptions/$subscriptionId'),
        headers: headers,
      );
      
      return handleResponse(response);
    } catch (e) {
      print('Error canceling subscription: $e');
      throw Exception('Failed to cancel subscription: $e');
    }
  }
  
  // Process a payment in the backend
  static Future<Map<String, dynamic>> processPayment({
    required int userId,
    required int serialId,
    required double amount,
    required String currency,
    required String paymentMethodId,
    String? customerId,
  }) async {
    try {
      // 1. Create or get Stripe customer
      Map<String, dynamic> customer;
      if (customerId == null) {
        // Get user details from database
        final user = await BackendApiService.executeQuery(
          'SELECT * FROM Users WHERE id = ?',
          [userId]
        );
        
        if (user.isEmpty) {
          throw Exception('User not found');
        }
        
        // Create Stripe customer
        customer = await createCustomer(
          email: user.first['email'],
          name: user.first['name'],
        );
        
        // Store customer ID in database
        await BackendApiService.executeQuery(
          'UPDATE Users SET stripe_customer_id = ? WHERE id = ?',
          [customer['id'], userId]
        );
      } else {
        customer = {'id': customerId};
      }
      
      // 2. Create payment intent
      final amountInCents = (amount * 100).round().toString();
      final paymentIntent = await createPaymentIntent(
        amount: amountInCents,
        currency: currency.toLowerCase(),
        customerId: customer['id'],
        paymentMethodId: paymentMethodId,
        metadata: {
          'user_id': userId,
          'serial_id': serialId,
        },
      );
      
      // 3. Store payment in database
      final paymentStatus = paymentIntent['status'];
      final paymentId = await BackendApiService.executeInsert(
        'INSERT INTO Payments (user_id, serial_id, amount, currency, payment_status, stripe_payment_id) VALUES (?, ?, ?, ?, ?, ?)',
        [userId, serialId, amount, currency, paymentStatus, paymentIntent['id']]
      );
      
      // 4. If payment requires additional action, return the client secret
      if (paymentStatus == 'requires_action' || 
          paymentStatus == 'requires_source_action') {
        return {
          'requires_action': true,
          'payment_intent_client_secret': paymentIntent['client_secret'],
          'payment_id': paymentId,
        };
      }
      
      // 5. If payment succeeded, update payment status
      if (paymentStatus == 'succeeded') {
        await BackendApiService.executeQuery(
          'UPDATE Payments SET payment_status = ? WHERE id = ?',
          ['completed', paymentId]
        );
        
        // Create subscription record
        final endDate = DateTime.now().add(const Duration(days: 30));
        await BackendApiService.createSubscription(userId, serialId, endDate);
      }
      
      return {
        'success': paymentStatus == 'succeeded',
        'status': paymentStatus,
        'payment_id': paymentId,
        'payment_intent_id': paymentIntent['id'],
      };
    } catch (e) {
      print('Error processing payment: $e');
      throw Exception('Failed to process payment: $e');
    }
  }
  
  // Update payment status after client-side confirmation
  static Future<Map<String, dynamic>> updatePaymentStatus({
    required int paymentId,
    required String paymentIntentId,
  }) async {
    try {
      // Get payment intent from Stripe
      final response = await http.get(
        Uri.parse('$_paymentIntentUrl/$paymentIntentId'),
        headers: headers,
      );
      
      final paymentIntent = handleResponse(response);
      final paymentStatus = paymentIntent['status'];
      
      // Update payment status in database
      String dbStatus;
      if (paymentStatus == 'succeeded') {
        dbStatus = 'completed';
      } else if (paymentStatus == 'canceled') {
        dbStatus = 'canceled';
      } else {
        dbStatus = 'failed';
      }
      
      await BackendApiService.executeQuery(
        'UPDATE Payments SET payment_status = ? WHERE id = ?',
        [dbStatus, paymentId]
      );
      
      // If payment succeeded, create subscription
      if (paymentStatus == 'succeeded') {
        // Get payment details
        final payment = await BackendApiService.executeQuery(
          'SELECT * FROM Payments WHERE id = ?',
          [paymentId]
        );
        
        if (payment.isNotEmpty) {
          final userId = payment.first['user_id'];
          final serialId = payment.first['serial_id'];
          
          // Create subscription record
          final endDate = DateTime.now().add(const Duration(days: 30));
          await BackendApiService.createSubscription(userId, serialId, endDate);
        }
      }
      
      return {
        'success': paymentStatus == 'succeeded',
        'status': paymentStatus,
      };
    } catch (e) {
      print('Error updating payment status: $e');
      throw Exception('Failed to update payment status: $e');
    }
  }
  
  // Handle Stripe API response
  static Map<String, dynamic> handleResponse(http.Response response) {  // Removed underscore
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      print('Stripe API error: ${response.body}');
      throw Exception('Stripe API error: ${response.body}');
    }
  }
}
