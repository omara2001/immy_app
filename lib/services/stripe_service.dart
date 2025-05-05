import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:immy_app/services/stripe_sync_service.dart';
import 'backend_api_service.dart';

class StripeService {
  static const String _defaultSecretKey = 'sk_test_51R00wJP1l4vbhTn5Xfe5zWNZrVtHyA7EeP1REpL92RXarOtVRelDEPPHBNdvEdhWRFMd66CWmOLd2cCI2ZF6aAls00jM6x0sdT';
  static const String baseUrl = 'https://api.stripe.com/v1';

  static String? _overrideSecretKey;

  static void initialize({
    required String secretKey,
    String? publishableKey,
    bool testMode = false, // for compatibility
  }) {
    if (secretKey.isEmpty) throw Exception('Stripe secret key cannot be empty');
    _overrideSecretKey = secretKey;
    print('[StripeService] Initialized');
  }

  static Map<String, String> get headers => {
        'Authorization': 'Bearer ${_overrideSecretKey ?? _defaultSecretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

  // ========== CUSTOMER ==========
  static Future<Map<String, dynamic>> createCustomer({
    required String email,
    String? name,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customers'),
      headers: headers,
      body: {
        'email': email,
        if (name != null) 'name': name,
      },
    );
    return _handleResponse(response);
  }

  static Future<String> getOrCreateCustomerId(int userId) async {
    // For test/demo users, create an actual Stripe customer instead of using mock IDs
    if (userId == 0 || userId == 999) {
      try {
        // First, ensure the test user exists in our database
        await _ensureTestUserExists(userId);
        
        // Try to find an existing test customer
        final response = await http.get(
          Uri.parse('$baseUrl/customers?email=test@example.com&limit=1'),
          headers: headers,
        );
        final result = _handleResponse(response);
        
        if (result['data'] != null && result['data'].isNotEmpty) {
          return result['data'][0]['id'];
        }
        
        // Create a real test customer in Stripe
        final newCustomer = await createCustomer(
          email: 'test@example.com',
          name: 'Test User',
        );
        return newCustomer['id'];
      } catch (e) {
        print('Error creating test customer: $e');
        throw Exception('Failed to create test customer in Stripe');
      }
    }

    final userRows = await BackendApiService.executeQuery(
      'SELECT id, email, name, stripe_customer_id FROM Users WHERE id = ?',
      [userId],
    );
    
    if (userRows.isEmpty) {
      throw Exception('User not found');
    }

    final user = userRows.first;
    final currentCustomerId = user['stripe_customer_id'];

    if (currentCustomerId != null && currentCustomerId.toString().isNotEmpty) {
      return currentCustomerId;
    }

    final newCustomer = await createCustomer(
      email: user['email'],
      name: user['name'],
    );

    final newCustomerId = newCustomer['id'];

    await BackendApiService.executeQuery(
      'UPDATE Users SET stripe_customer_id = ? WHERE id = ?',
      [newCustomerId, userId],
    );

    return newCustomerId;
  }

  // ========== PAYMENT INTENT ==========
  static Future<Map<String, dynamic>> createPaymentIntent({
    required String amount,
    required String currency,
    String? customerId,
    String? paymentMethodId,
    Map<String, String>? metadata,
  }) async {
    final body = {
      'amount': amount,
      'currency': currency,
      'payment_method_types[]': 'card',
      'confirmation_method': 'automatic',
      'confirm': 'false',
      'description': 'Immy App Subscription',
      'metadata[integration_check]': 'accept_a_payment',
    };

    if (customerId != null) body['customer'] = customerId;
    if (paymentMethodId != null) body['payment_method'] = paymentMethodId;
    
    // Add metadata if provided
    if (metadata != null) {
      metadata.forEach((key, value) {
        body['metadata[$key]'] = value;
      });
    }

    final response = await http.post(
      Uri.parse('$baseUrl/payment_intents'),
      headers: headers,
      body: body,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> confirmPaymentIntent({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment_intents/$paymentIntentId/confirm'),
      headers: headers,
      body: {
        'payment_method': paymentMethodId,
      },
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> retrievePaymentIntent(String paymentIntentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/payment_intents/$paymentIntentId'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updatePaymentIntent({
    required String paymentIntentId,
    String? paymentMethodId,
    Map<String, String>? metadata,
  }) async {
    final body = <String, String>{};
    if (paymentMethodId != null) body['payment_method'] = paymentMethodId;
    
    // Add metadata if provided
    if (metadata != null) {
      metadata.forEach((key, value) {
        body['metadata[$key]'] = value;
      });
    }

    final response = await http.post(
      Uri.parse('$baseUrl/payment_intents/$paymentIntentId'),
      headers: headers,
      body: body,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> retryPaymentIntent({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    // First update the payment intent with the new payment method
    await updatePaymentIntent(
      paymentIntentId: paymentIntentId,
      paymentMethodId: paymentMethodId,
    );
    
    // Then confirm the payment intent
    return await confirmPaymentIntent(
      paymentIntentId: paymentIntentId,
      paymentMethodId: paymentMethodId,
    );
  }

  // ========== SETUP INTENT ==========
  static Future<Map<String, dynamic>> createSetupIntent({
    required int userId,
    String? customerId,
  }) async {
    customerId ??= await getOrCreateCustomerId(userId);

    final response = await http.post(
      Uri.parse('$baseUrl/setup_intents'),
      headers: headers,
      body: {
        'customer': customerId,
        'payment_method_types[]': 'card',
        'usage': 'off_session',
      },
    );

    final result = _handleResponse(response);
    return {
      'client_secret': result['client_secret'],
      'setup_intent_id': result['id'],
    };
  }

  // ========== PAYMENT METHOD ==========
  static Future<Map<String, dynamic>> attachPaymentMethodToCustomer({
    required String paymentMethodId,
    required String customerId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment_methods/$paymentMethodId/attach'),
      headers: headers,
      body: {
        'customer': customerId,
      },
    );
    return _handleResponse(response);
  }

  static Future<List<Map<String, dynamic>>> getCustomerPaymentMethods({
    required String customerId,
    String type = 'card',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/payment_methods?customer=$customerId&type=$type'),
      headers: headers,
    );
    final result = _handleResponse(response);
    return List<Map<String, dynamic>>.from(result['data']);
  }

  // ========== SUBSCRIPTION ==========
  static Future<Map<String, dynamic>> createSubscription({
    required String customerId,
    required String priceId,
    String? paymentMethodId,
    Map<String, String>? metadata,
  }) async {
    final body = {
      'customer': customerId,
      'items[0][price]': priceId,
    };
    
    if (paymentMethodId != null) {
      body['default_payment_method'] = paymentMethodId;
    }
    
    // Add metadata if provided
    if (metadata != null) {
      metadata.forEach((key, value) {
        body['metadata[$key]'] = value;
      });
    }

    final response = await http.post(
      Uri.parse('$baseUrl/subscriptions'),
      headers: headers,
      body: body,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> cancelSubscription({
    required String subscriptionId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/subscriptions/$subscriptionId'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  // ========== HEALTH CHECK ==========
  static Future<bool> testStripeConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customers?limit=1'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Stripe connection test failed: $e');
      return false;
    }
  }

  // ========== COMMON ==========
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      print('Stripe error: ${response.body}');
      throw Exception('Stripe API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Add this new method to check payments in Stripe
  static Future<List<Map<String, dynamic>>> getCustomerPayments(String customerId) async {
    try {
      // Get payment intents for this customer
      final response = await http.get(
        Uri.parse('$baseUrl/payment_intents?customer=$customerId&limit=10'),
        headers: headers,
      );
      final result = _handleResponse(response);
      return List<Map<String, dynamic>>.from(result['data']);
    } catch (e) {
      print('Error fetching customer payments from Stripe: $e');
      return [];
    }
  }

  // Add this method to sync payments with Stripe
  static Future<void> syncPaymentsWithStripe(int userId, String customerId) async {
    try {
      // Ensure user exists in database
      if (userId == 0 || userId == 999) {
        await _ensureTestUserExists(userId);
      }
      
      // Use the new StripeSyncService for better synchronization
      final syncService = StripeSyncService();
      await syncService.syncUserWithStripe(userId, customerId);
    } catch (e) {
      print('Error syncing payments with Stripe: $e');
    }
  }

  // Add this helper method to ensure test users exist in the database
  static Future<void> _ensureTestUserExists(int userId) async {
    try {
      // Check if user exists
      final users = await BackendApiService.executeQuery(
        'SELECT id FROM Users WHERE id = ?',
        [userId]
      );
      
      if (users.isEmpty) {
        // Create the test user if it doesn't exist
        await BackendApiService.executeQuery(
          'INSERT INTO Users (id, email, name) VALUES (?, ?, ?)',
          [userId, 'test@example.com', 'Test User']
        );
        print('Created test user with ID: $userId');
      }
    } catch (e) {
      print('Error ensuring test user exists: $e');
    }
  }
}