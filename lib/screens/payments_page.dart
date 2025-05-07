import 'package:flutter/material.dart' hide Card;
import '../services/backend_api_service.dart';
import '../widgets/subscription_banner.dart';
import 'dart:convert';
import '../services/stripe_service.dart';
import '../services/stripe_sync_service.dart';
import '../services/payment_processor.dart';
import 'package:flutter/material.dart' as material;
import '../services/users_auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _payments = [];
  int _userId = 0;
  String? _cardBrand;
  String? _cardLast4;
  final AuthService _authService = AuthService();
  bool _demoMode = false;
  final StripeSyncService _syncService = StripeSyncService();
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get the current user
      final user = await _authService.getCurrentUser();
      
      if (user == null) {
        // If no user, use demo mode with simulated data
        setState(() {
          _demoMode = true; // Set demo mode flag to true
          _isLoading = false;
          _errorMessage = "Demo mode: Using simulated payment data";
          _subscriptions = _getDemoSubscriptions();
          _payments = _getDemoPayments();
          _cardBrand = 'Visa';
          _cardLast4 = '4242';
        });
        return;
      }
      
      // User is authenticated, turn off demo mode
      setState(() {
        _demoMode = false;
        _userId = user.id;
      });
      
      // Get customer ID for this user
      final customerId = await _getCustomerId();
      
      // IMPORTANT: Sync payments with Stripe before fetching local data
      try {
        await _syncService.syncUserWithStripe(_userId, customerId);
        print('Successfully synced payments with Stripe');
      } catch (e) {
        print('Error during Stripe sync: $e');
        // Continue anyway to show whatever data we have
      }
      
      // Fetch the user's subscriptions from our API
      try {
        final userSubscriptions = await BackendApiService.getUserSubscriptions(_userId);
        setState(() {
          _subscriptions = userSubscriptions;
        });
        print('Loaded ${userSubscriptions.length} subscriptions');
      } catch (e) {
        print('Error fetching subscriptions: $e');
        setState(() {
          _subscriptions = _getDemoSubscriptions();
        });
      }
      
      // Fetch the user's payment history from our API
      try {
        final userPayments = await BackendApiService.getUserPayments(_userId);
        setState(() {
          _payments = userPayments;
        });
        print('Loaded ${userPayments.length} payments');
      } catch (e) {
        print('Error fetching payments: $e');
        setState(() {
          _payments = _getDemoPayments();
        });
      }
      
      // Get payment method details for the user
      try {
        final paymentMethods = await StripeService.getCustomerPaymentMethods(customerId: customerId);
        if (paymentMethods.isNotEmpty) {
          final card = paymentMethods.first['card'];
          setState(() {
            _cardBrand = card['brand'];
            _cardLast4 = card['last4'];
          });
        }
      } catch (e) {
        print('Error fetching payment methods: $e');
        setState(() {
          _cardBrand = 'Visa';
          _cardLast4 = '4242';
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }
  
  // Manual sync with Stripe
  Future<void> _manualSyncWithStripe() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });
    
    try {
      final customerId = await _getCustomerId();
      
      // Show a loading dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Syncing with Stripe'),
          content: const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Please wait...'),
            ],
          ),
        ),
      );
      
      // Perform the sync
      final result = await _syncService.syncUserWithStripe(_userId, customerId);
      
      // Close the dialog
      Navigator.of(context).pop();
      
      // Reload data
      await _loadData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync completed: ${result['payments']} payments and ${result['subscriptions']} subscriptions synced'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close the dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing with Stripe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
  
  void _updatePaymentMethod() async {
    try {
      if (_demoMode) {
        // For demo purposes, show a dialog
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Payment Method'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.credit_card, size: 48, color: Color(0xFF8B5CF6)),
                SizedBox(height: 16),
                Text(
                  'This is a demonstration. In a real app, you would be redirected to Stripe to update your payment method.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                child: const Text('Update'),
              ),
            ],
          ),
        );
        
        if (result == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment method updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
      
      // Get current user
      final user = await _authService.getCurrentUser();
      
      if (user == null) {
        setState(() {
          _errorMessage = 'Unable to retrieve user information';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Show processing dialog
      await _showPaymentProcessingDialog();
      
      // Get customer ID
      final customerId = await _getCustomerId();
      
      // Create a setup intent for updating payment method
      final setupIntentResult = await StripeService.createSetupIntent(
        userId: user.id,
        customerId: customerId,
      );
      
      final clientSecret = setupIntentResult['client_secret'];
      
      if (clientSecret == null) {
        // Close processing dialog
        Navigator.of(context).pop();
        throw Exception('Failed to create setup intent - client secret is null');
      }
      
      // Present the payment sheet for setup
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'Immy App',
          customerId: customerId,
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.purple,
            ),
          ),
        ),
      );
      
      // Close processing dialog
      Navigator.of(context).pop();
      
      // Show the payment sheet
      await Stripe.instance.presentPaymentSheet();
      
      // Payment method successfully updated if we get here
      
      // Refresh data
      setState(() {
        _isLoading = false;
      });
      
      await _loadData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment method updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Make sure processing dialog is closed
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update payment method: $e';
      });
      
      // Show detailed error dialog
      await _showStripeErrorDialog(e);
    }
  }
  
  Future<String> _getCustomerId() async {
    try {
      if (_userId == 0 || _userId == 999) {
        // For test users, use StripeService to get or create a real customer
        return await StripeService.getOrCreateCustomerId(_userId);
      }
      
      final users = await BackendApiService.executeQuery(
        'SELECT stripe_customer_id FROM Users WHERE id = ?',
        [_userId]
      );
      
      if (users.isEmpty || users.first['stripe_customer_id'] == null) {
        // Create a customer if it doesn't exist
        final customerData = await StripeService.createCustomer(
          email: 'customer$_userId@example.com',
          name: 'User $_userId',
        );
        
        // Update user with new customer ID
        await BackendApiService.executeQuery(
          'UPDATE Users SET stripe_customer_id = ? WHERE id = ?',
          [customerData['id'], _userId]
        );
        
        return customerData['id'];
      }
      
      return users.first['stripe_customer_id'];
    } catch (e) {
      print('Error getting customer ID: $e');
      // Return a stable mock ID for testing based on user ID
      return 'cus_mock_$_userId';
    }
  }
  
  void _navigateToSubscriptions() {
    Navigator.pushNamed(
      context, 
      '/subscription',
      arguments: {'userId': _userId}
    ).then((_) => _loadData());
  }
  
  Future<bool> _checkExistingPayment() async {
    try {
      // Get customer ID
      final customerId = await _getCustomerId();
      
      // Check Stripe for payments directly
      final stripePayments = await StripeService.getCustomerPayments(customerId);
      final hasStripePayment = stripePayments.any((payment) => payment['status'] == 'succeeded');
      
      if (hasStripePayment) {
        // Sync with local database
        await _syncService.syncUserWithStripe(_userId, customerId);
        
        // Refresh data
        await _loadData();
        return true;
      }
      
      // Check if there's already a completed payment for this user in local DB
      final payments = await BackendApiService.executeQuery(
        'SELECT * FROM Payments WHERE user_id = ? AND payment_status = ?',
        [_userId, 'completed']
      );
      
      if (payments.isNotEmpty) {
        // Check if there's an active subscription
        final subscriptions = await BackendApiService.executeQuery(
          'SELECT * FROM Subscriptions WHERE user_id = ? AND status = ? AND end_date > NOW()',
          [_userId, 'active']
        );
        
        if (subscriptions.isEmpty) {
          // Payment exists but no active subscription, create one
          final endDate = DateTime.now().add(const Duration(days: 30));
          await BackendApiService.createSubscription(
            _userId, 
            0, // Use 0 for test users
            endDate,
            stripeSubscriptionId: payments.first['stripe_payment_id'],
            stripePriceId: 'price_standard'
          );
          
          // Refresh data
          await _loadData();
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking existing payment: $e');
      return false;
    }
  }
  
  Future<void> _subscribeNow() async {
    try {
      // Get the current user
      final user = await _authService.getCurrentUser();
      
      if (user == null) {
        setState(() {
          _demoMode = true; // Set demo mode flag to true
          _errorMessage = 'Could not determine user ID. Using demo mode.';
        });
        await _testMockPayment(); // Use the test mock payment instead of demo flow
        return;
      }
      
      // Set user ID from the current user
      _userId = user.id;
      
      // Check if user already has a payment
      final hasExistingPayment = await _checkExistingPayment();
      if (hasExistingPayment) {
        // User already has a payment, show success dialog
        await _showPaymentSuccessDialog();
        return;
      }
      
      // Show loading state
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Get or create a serial number for the user
      final serials = await _getOrCreateSerialNumber();
      
      if (serials.isEmpty) {
        throw Exception('Failed to get or create a serial number');
      }
      
      final serialId = serials.first['id'];
      
      // Check if we're running on Chrome vs Android/iOS
      final bool isWeb = identical(0, 0.0);
      
      if (isWeb) {
        print('Running on web, using mock payment flow');
        await _testMockPayment();
        return;
      }
      
      // Show processing dialog
      await _showPaymentProcessingDialog();
      
      // Use PaymentProcessor to handle the payment
      final userEmail = user.email;
      if (userEmail == null || userEmail.isEmpty) {
        // Try to get the email from the database
        final userInfo = await BackendApiService.executeQuery(
          'SELECT email, name FROM Users WHERE id = ?',
          [_userId]
        );
        
        if (userInfo.isNotEmpty && userInfo.first['email'] != null) {
          final customerEmail = userInfo.first['email'].toString();
          final customerName = userInfo.first['name']?.toString() ?? user.name;
          
          print('Using email from database: $customerEmail for user $customerName');
          
          final result = await PaymentProcessor.processPayment(
            userId: _userId,
            serialId: serialId,
            amount: 7.99,
            currency: 'gbp',
            customerEmail: customerEmail,
            customerName: customerName,
          );
          
          // Close processing dialog
          Navigator.of(context).pop();
          
          if (result['success'] == true) {
            // Refresh data
            setState(() {
              _isLoading = false;
            });
            
            await _loadData();
            
            // Show success dialog
            await _showPaymentSuccessDialog();
          } else {
            // Handle error
            setState(() {
              _isLoading = false;
              _errorMessage = 'Payment failed: ${result['error']}';
            });
            
            // Show error dialog
            await _showStripeErrorDialog(result['error']);
          }
        } else {
          // No email found in database, show error
          Navigator.of(context).pop(); // Close dialog
          
          setState(() {
            _isLoading = false;
            _errorMessage = 'Missing email address. Please update your profile.';
          });
        }
      } else {
        // We have the email from the user object
        print('Using email from user object: $userEmail');
        
        final result = await PaymentProcessor.processPayment(
          userId: _userId,
          serialId: serialId,
          amount: 7.99,
          currency: 'gbp',
          customerEmail: userEmail,
          customerName: user.name,
        );
        
        // Close processing dialog
        Navigator.of(context).pop();
        
        if (result['success'] == true) {
          // Refresh data
          setState(() {
            _isLoading = false;
          });
          
          await _loadData();
          
          // Show success dialog
          await _showPaymentSuccessDialog();
        } else {
          // Handle error
          setState(() {
            _isLoading = false;
            _errorMessage = 'Payment failed: ${result['error']}';
          });
          
          // Show error dialog
          await _showStripeErrorDialog(result['error']);
        }
      }
    } catch (e) {
      // Make sure processing dialog is closed
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _errorMessage = 'Failed to process subscription: ${e.toString()}';
        _isLoading = false;
      });
      
      // Show error dialog
      await _showStripeErrorDialog(e);
    }
  }
  
  // Helper method to get or create a serial number
  Future<List<Map<String, dynamic>>> _getOrCreateSerialNumber() async {
    try {
      // Try to get existing serial numbers
      List<Map<String, dynamic>> serials = await BackendApiService.executeQuery(
        'SELECT * FROM SerialNumbers WHERE user_id = ?',
        [_userId]
      );
      
      if (serials.isNotEmpty) {
        return serials;
      }
      
      // Create a new serial number
      final serialNumber = 'SN-${_userId}-${DateTime.now().millisecondsSinceEpoch}';
      final result = await BackendApiService.executeInsert(
        'INSERT INTO SerialNumbers (user_id, serial, created_at) VALUES (?, ?, NOW())',
        [_userId, serialNumber]
      );
      
      if (result > 0) {
        // Fetch the newly created serial
        serials = await BackendApiService.executeQuery(
          'SELECT * FROM SerialNumbers WHERE id = ?',
          [result]
        );
        
        return serials;
      }
      
      // Fallback - create a mock serial
      return [{
        'id': 1,
        'serial': 'TEST-SERIAL-123',
        'user_id': _userId
      }];
    } catch (e) {
      print('Error getting or creating serial number: $e');
      // Return a fallback serial number
      return [{
        'id': 1,
        'serial': 'TEST-SERIAL-123',
        'user_id': _userId
      }];
    }
  }
  
  // Demo helper methods
  List<Map<String, dynamic>> _getDemoSubscriptions() {
    return [
      {
        'id': 'sub_demo123',
        'status': 'active',
        'start_date': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'price': {
          'amount': 7.99,
          'currency': 'GBP',
          'interval': 'month'
        }
      }
    ];
  }

  List<Map<String, dynamic>> _getDemoPayments() {
    return [
      {
        'id': 'pay_demo123',
        'amount': 7.99,
        'currency': 'GBP',
        'status': 'succeeded',
        'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      },
      {
        'id': 'pay_demo456',
        'amount': 7.99,
        'currency': 'GBP',
        'status': 'succeeded',
        'created_at': DateTime.now().subtract(const Duration(days: 60)).toIso8601String(),
      }
    ];
  }

  Future<void> _showDemoPaymentFlow() async {
    // Show a demo payment flow dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demo Payment Process'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.credit_card, size: 48, color: Color(0xFF8B5CF6)),
            SizedBox(height: 16),
            Text(
              'This is a demonstration of the payment flow. In a real app, you would be redirected to Stripe to complete your payment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: const Text('Complete Demo Payment'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Simulate successful payment
      setState(() {
        _errorMessage = null;
        _subscriptions = _getDemoSubscriptions();
        _payments = _getDemoPayments();
        _cardBrand = 'Visa';
        _cardLast4 = '4242';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo subscription activated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Check if user has active subscription
    final hasActiveSubscription = _subscriptions.any((sub) {
      if (sub['end_date'] == null) return false;
      final endDate = _parseDateTime(sub['end_date']);
      return sub['status'] == 'active' && endDate.isAfter(DateTime.now());
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subscription banner
                        SubscriptionBanner(
                          isActive: _subscriptions.any((sub) => sub['status'] == 'active'),
                          onActivateTap: _subscribeNow,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Current Plan
                        const Text(
                          'Current Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCurrentPlan(),
                        
                        const SizedBox(height: 32),
                        
                        // Payment Method
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentMethod(),
                        
                        const SizedBox(height: 32),
                        
                        // Payment History
                        const Text(
                          'Payment History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentHistory(),
                        
                        // Add support link section at the bottom
                        const SizedBox(height: 32),
                        _buildSupportSection(),
                        
                        // Add padding at the bottom for the error banner
                        SizedBox(height: _errorMessage != null ? 70 : 0),
                      ],
                    ),
                  ),
                  
                  // Error Banner at the bottom
                  if (_errorMessage != null && !_errorMessage!.contains('Demo mode'))
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.red,
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                  // Demo mode indicator (less prominent than an error)
                  if (_errorMessage != null && _errorMessage!.contains('Demo mode'))
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.amber.shade700,
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Demo mode active - subscription data is simulated',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // Add a manual sync button to the UI in the _buildCurrentPlan method
  Widget _buildCurrentPlan() {
    // Check if there's an active subscription
    final hasActiveSubscription = _subscriptions.any((sub) => 
      sub['status'] == 'active' && 
      _parseDateTime(sub['end_date']).isAfter(DateTime.now())
    );
    
    // Get the next payment date
    DateTime nextPaymentDate;
    if (_payments.isNotEmpty) {
      try {
        nextPaymentDate = _parseDateTime(_payments.first['created_at']).add(const Duration(days: 30));
      } catch (e) {
        print('Error calculating next payment date: $e');
        nextPaymentDate = DateTime.now().add(const Duration(days: 30));
      }
    } else {
      nextPaymentDate = DateTime.now().add(const Duration(days: 30));
    }
      
    // Format the next payment date as Month Day, Year
    final String nextPaymentDateFormatted = 
      '${_getMonthName(nextPaymentDate.month)} ${nextPaymentDate.day}, ${nextPaymentDate.year}';
    
    return material.Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasActiveSubscription ? 'Premium Monthly Subscription' : 'No Active Subscription',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: hasActiveSubscription 
                        ? const Color(0xFF8B5CF6) // purple-600
                        : const Color(0xFF6B7280), // gray-500
                  ),
                ),
                if (hasActiveSubscription)
                  TextButton(
                    onPressed: _navigateToSubscriptions,
                    child: const Text('Manage'),
                  ),
              ],
            ),
            
            if (hasActiveSubscription) ...[
              // Price and Payment Details
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '£7.99',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    'per month',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280), // gray-500
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Payment Date
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Next payment: $nextPaymentDateFormatted',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563), // gray-600
                    ),
                  ),
                ],
              ),
              
              // Add a manual sync button
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSyncing ? null : _manualSyncWithStripe,
                icon: _isSyncing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        ),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync with Stripe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ] else ...[
              // Subscribe Now Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _demoMode ? _testMockPayment : _subscribeNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Subscribe Now',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unlock all premium features with a monthly subscription.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280), // gray-500
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod() {
    if (_cardLast4 == null) {
      return material.Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.credit_card_outlined,
                size: 48,
                color: Color(0xFFD1D5DB),
              ),
              const SizedBox(height: 12),
              const Text(
                'No payment method on file',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add a payment method to subscribe',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _updatePaymentMethod,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Payment Method'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return material.Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _getCardBrandColor(_cardBrand).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.credit_card,
                      size: 20,
                      color: _getCardBrandColor(_cardBrand),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_cardBrand',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '•••• •••• •••• $_cardLast4',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Expires 12/2024',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _updatePaymentMethod,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Update'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    if (_payments.isEmpty) {
      return material.Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Color(0xFFD1D5DB),
              ),
              const SizedBox(height: 16),
              const Text(
                'No payment history yet',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your payment history will appear here after your first subscription payment',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return material.Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: _payments.map((payment) {
                final date = _parseDateTime(payment['created_at']);
                final dateFormatted = '${_getMonthName(date.month)} ${date.day}, ${date.year}';
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt,
                          size: 20,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Monthly Subscription',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              dateFormatted,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '£${payment['amount']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  // Navigate to payment history screen
                  Navigator.pushNamed(
                    context,
                    '/payment_history',
                    arguments: {'userId': _userId}
                  );
                },
                icon: const Icon(Icons.history, size: 16),
                label: const Text('View Complete History'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return material.Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.support_agent,
                size: 24,
                color: Color(0xFFDB2777),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need Help with Billing?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Our support team is available 24/7 to help with any billing questions or subscription issues you may have.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _contactSupport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDF2F8),
                foregroundColor: const Color(0xFFDB2777),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Contact'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCardBrandColor(String? brand) {
    switch (brand?.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1434CB); // Visa blue
      case 'mastercard':
        return const Color(0xFFFF5F00); // Mastercard orange
      case 'amex':
        return const Color(0xFF2E77BC); // Amex blue
      default:
        return const Color(0xFF6B7280); // gray-500
    }
  }

  void _contactSupport() {
    // Implementation for contacting support
    launchUrl(Uri.parse('mailto:support@example.com?subject=Subscription%20Support'));
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  // Show a payment processing dialog
  Future<void> _showPaymentProcessingDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Processing Payment'),
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
              SizedBox(width: 16),
              Text('Please wait...'),
            ],
          ),
        ),
      ),
    );
  }

  // Show a payment success dialog
  Future<void> _showPaymentSuccessDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Color(0xFF16A34A),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Your payment was processed successfully. Your subscription is now active.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show a payment processing dialog with error details
  Future<void> _showStripeErrorDialog(dynamic error) async {
    String errorMessage = 'An unknown error occurred';
    String errorCode = '';
    String specificSolution = '';
    
    // Extract error details
    if (error is Exception) {
      errorMessage = error.toString();
      
      // Try to extract detailed Stripe error information
      if (errorMessage.contains('resource_missing')) {
        errorCode = 'resource_missing';
        specificSolution = 'The Stripe API keys may be invalid or the resource no longer exists. Please check your configuration.';
      } else if (errorMessage.contains('authentication_required')) {
        errorCode = 'authentication_required';
        specificSolution = 'Your card requires authentication. Try using a different card or contact your bank.';
      } else if (errorMessage.contains('card_declined')) {
        errorCode = 'card_declined';
        specificSolution = 'Your card was declined. Try using a different payment method.';
      } else if (errorMessage.contains('PlatformException')) {
        errorCode = 'platform_error';
        specificSolution = 'There is an issue with the Stripe SDK integration. Try restarting the app or using mock payment for testing.';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'There was a problem processing your payment:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(errorMessage),
              if (errorCode.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Error code: $errorCode', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
              if (specificSolution.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Possible solution: $specificSolution'),
              ],
              const SizedBox(height: 16),
              const Text(
                'General troubleshooting steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Ensure you have a working internet connection'),
              const Text('2. Restart the app and try again'),
              const Text('3. If using an emulator, try on a physical device'),
              const Text('4. Check if you\'re using the latest app version'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _testMockPayment(); // Use the mock payment instead
                },
                child: const Text('Use Mock Payment for Testing'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Test payment implementation for development and testing
  Future<void> _testMockPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _showPaymentProcessingDialog();
      
      // Get user's serial numbers or use a default
      int serialId = 1; // Default serial ID
      
      try {
        // Try to get actual serial numbers if available
        final serials = await BackendApiService.executeQuery(
          'SELECT * FROM SerialNumbers WHERE user_id = ?',
          [_userId]
        );
        
        if (serials.isNotEmpty) {
          serialId = serials.first['id'];
        }
      } catch (e) {
        print('Using default serial ID for mock payment: $e');
      }
      
      // Simulate processing time
      await Future.delayed(const Duration(seconds: 2));
      
      // Create mock payment in the database with correct fields
      final mockPaymentId = 'pi_mock_${DateTime.now().millisecondsSinceEpoch}';
      final paymentAmount = 7.99;
      final paymentCurrency = 'gbp';
      final now = DateTime.now();
      
      try {
        // Create payment record in database
        await BackendApiService.createPayment(
          _userId,
          serialId,
          paymentAmount,
          paymentCurrency,
          stripePaymentId: mockPaymentId,
          stripePaymentMethodId: 'pm_mock_card_visa'
        );
        
        print('Created mock payment record in database');
      } catch (e) {
        print('Error creating mock payment in database: $e');
        // Continue anyway - mock data will still show in UI
      }
      
      // Create a mock subscription
      final endDate = now.add(const Duration(days: 30));
      
      try {
        // Create subscription in database
        await BackendApiService.createSubscription(
          _userId,
          serialId,
          endDate,
          stripeSubscriptionId: 'sub_mock_${now.millisecondsSinceEpoch}',
          stripePriceId: 'price_standard'
        );
        
        print('Created mock subscription record in database');
      } catch (e) {
        print('Error creating mock subscription in database: $e');
      }
      
      // Create payment data for UI
      final paymentData = {
        'id': mockPaymentId,
        'amount': paymentAmount,
        'currency': paymentCurrency,
        'status': 'succeeded',
        'created_at': now.toIso8601String(),
      };
      
      // Create a mock subscription for UI
      final mockSubscription = {
        'id': now.millisecondsSinceEpoch,
        'user_id': _userId,
        'serial_id': serialId,
        'start_date': now.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'active',
        'stripe_subscription_id': 'sub_mock_${now.millisecondsSinceEpoch}',
        'stripe_price_id': 'price_standard',
      };
      
      // Set payment method info if none exists
      if (_cardBrand == null || _cardLast4 == null) {
        setState(() {
          _cardBrand = 'Visa';
          _cardLast4 = '4242';
        });
      }
      
      // Close processing dialog
      Navigator.of(context).pop();
      
      // Update UI with new data
      setState(() {
        _isLoading = false;
        _payments.insert(0, paymentData);
        _subscriptions.insert(0, mockSubscription);
      });
      
      // Show success dialog
      await _showPaymentSuccessDialog();
      
    } catch (e) {
      // Close processing dialog if open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Mock payment test failed: $e';
      });
    }
  }

  // Add a helper method to safely parse DateTime
  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('Error parsing date: $e');
      }
    }
    return DateTime.now(); // Fallback
  }
}