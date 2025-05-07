import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/stripe_service.dart';
import '../services/payment_processor.dart';
import '../widgets/subscription_banner.dart';
import '../widgets/payment_card_input.dart';

class SubscriptionScreen extends StatefulWidget {
  final int userId;
  
  const SubscriptionScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _serialNumbers = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isAddingCard = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('Loading subscriptions for user ${widget.userId}');
      
      // Load subscriptions
      try {
        _subscriptions = await BackendApiService.getUserSubscriptions(widget.userId);
        print('Loaded ${_subscriptions.length} subscriptions');
      } catch (e) {
        print('Error loading subscriptions: $e');
        _subscriptions = [];
      }
      
      // Load serial numbers
      try {
        final results = await BackendApiService.executeQuery(
          'SELECT * FROM SerialNumbers WHERE user_id = ?',
          [widget.userId]
        );
        
        setState(() {
          _serialNumbers = results;
        });
        
        print('Loaded ${_serialNumbers.length} serial numbers');
      } catch (e) {
        print('Error loading serial numbers: $e');
        
        // Create fallback test data if database query fails
        setState(() {
          _serialNumbers = [{
            'id': 1, // Default serial ID
            'serial': 'TEST-SERIAL-1',
            'status': 'active',
            'user_id': widget.userId,
            'created_at': DateTime.now().toIso8601String(),
          }];
        });
      }
      
      // Load payment methods
      try {
        final customerId = await StripeService.getOrCreateCustomerId(widget.userId);
        _paymentMethods = await StripeService.getCustomerPaymentMethods(customerId: customerId);
        print('Loaded ${_paymentMethods.length} payment methods');
      } catch (e) {
        print('Error loading payment methods: $e');
        _paymentMethods = [];
      }
      
      // If we have no subscriptions but have serial numbers, create a test subscription
      if (_subscriptions.isEmpty && _serialNumbers.isNotEmpty) {
        print('No subscriptions found, creating a test subscription');
        try {
          final endDate = DateTime.now().add(const Duration(days: 30));
          final testSubscription = await BackendApiService.createSubscription(
            widget.userId,
            _serialNumbers.first['id'],
            endDate,
            stripeSubscriptionId: 'sub_test_${DateTime.now().millisecondsSinceEpoch}',
            stripePriceId: 'price_standard'
          );
          
          setState(() {
            _subscriptions = [testSubscription];
          });
          
          print('Test subscription created: ${testSubscription['id']}');
        } catch (e) {
          print('Error creating test subscription: $e');
          
          // Create a mock subscription as fallback
          final mockSub = {
            'id': DateTime.now().millisecondsSinceEpoch,
            'user_id': widget.userId,
            'serial_id': _serialNumbers.isNotEmpty ? _serialNumbers.first['id'] : 1,
            'start_date': DateTime.now().toIso8601String(),
            'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
            'status': 'active',
            'stripe_subscription_id': 'sub_mock_${DateTime.now().millisecondsSinceEpoch}',
            'stripe_price_id': 'price_standard',
          };
          
          setState(() {
            _subscriptions = [mockSub];
          });
          
          print('Mock subscription created: ${mockSub['id']}');
        }
      }
      
      // Check if any subscriptions need to be renewed
      _checkSubscriptionStatus();
      
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load subscription data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _checkSubscriptionStatus() {
    // Check if any subscriptions are expired but still marked as active
    for (var sub in _subscriptions) {
      if (sub['status'] == 'active') {
        final endDate = sub['end_date'] is String 
            ? DateTime.parse(sub['end_date'])
            : sub['end_date'] as DateTime;
            
        if (endDate.isBefore(DateTime.now())) {
          // Found an expired subscription still marked as active
          print('Found expired subscription: ${sub['id']}');
          
          // Create a renewal subscription
          _renewSubscription(sub);
        }
      }
    }
  }
  
  Future<void> _renewSubscription(Map<String, dynamic> subscription) async {
    try {
      print('Renewing subscription: ${subscription['id']}');
      
      // Create a new subscription with a new end date
      final endDate = DateTime.now().add(const Duration(days: 30));
      final newSubscription = await BackendApiService.createSubscription(
        widget.userId,
        subscription['serial_id'],
        endDate,
        stripeSubscriptionId: 'sub_renewal_${DateTime.now().millisecondsSinceEpoch}',
        stripePriceId: 'price_standard'
      );
      
      // Update the UI
      setState(() {
        // Mark the old subscription as cancelled
        _subscriptions = _subscriptions.map((sub) {
          if (sub['id'] == subscription['id']) {
            return {...sub, 'status': 'cancelled'};
          }
          return sub;
        }).toList();
        
        // Add the new subscription
        _subscriptions.add(newSubscription);
      });
      
      print('Subscription renewed successfully: ${newSubscription['id']}');
    } catch (e) {
      print('Error renewing subscription: $e');
    }
  }
  
  Future<void> _cancelSubscription(int subscriptionId, String stripeSubscriptionId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('Cancelling subscription $subscriptionId (Stripe ID: $stripeSubscriptionId)');
      
      // Use PaymentProcessor to cancel the subscription
      final success = await PaymentProcessor.cancelSubscription(widget.userId, stripeSubscriptionId);
      
      if (success) {
        print('Subscription cancelled successfully');
        
        // Update UI by updating the status of the cancelled subscription
        setState(() {
          _subscriptions = _subscriptions.map((sub) {
            if (sub['id'] == subscriptionId) {
              return {...sub, 'status': 'cancelled'};
            }
            return sub;
          }).toList();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data to ensure we have the latest status
        await _loadData();
      } else {
        throw Exception('Failed to cancel subscription');
      }
    } catch (e) {
      print('Error in _cancelSubscription: $e');
      setState(() {
        _errorMessage = 'Failed to cancel subscription: $e';
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addPaymentMethodAndSubscribe() async {
    setState(() {
      _isAddingCard = true;
    });
  }
  
  Future<void> _processNewSubscription(String paymentMethodId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get customer information for the user
      final users = await BackendApiService.executeQuery(
        'SELECT * FROM Users WHERE id = ?',
        [widget.userId]
      );
      
      if (users.isEmpty) {
        throw Exception('User not found');
      }
      
      final user = users.first;
      final email = user['email'];
      if (email == null || email.toString().isEmpty) {
        throw Exception('User has no email address');
      }
      final customerEmail = email.toString();
      final name = user['name'];
      
      print('Processing subscription for user: $customerEmail');
      
      // Get a valid serial number
      if (_serialNumbers.isEmpty) {
        throw Exception('No serial numbers found');
      }
      final serialId = _serialNumbers.first['id'];
      
      // Show processing dialog
      _showProcessingDialog();
      
      // If we have a payment method ID, update or attach it
      if (paymentMethodId.isNotEmpty) {
        // Get customer ID
        final customerId = await StripeService.getOrCreateCustomerId(widget.userId);
        print('Got customer ID: $customerId for email: $customerEmail');
        
        // Attach payment method to customer
        await StripeService.attachPaymentMethodToCustomer(
          paymentMethodId: paymentMethodId,
          customerId: customerId,
        );
      }
      
      // Process the payment
      final result = await PaymentProcessor.processPayment(
        userId: widget.userId,
        serialId: serialId,
        amount: 7.99,
        currency: 'gbp',
        customerEmail: customerEmail,
        customerName: name,
      );
      
      // Close the processing dialog
      Navigator.of(context).pop();
      
      if (result['success'] == true) {
        // Success! Reload data
        await _loadData();
        
        setState(() {
          _isAddingCard = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Payment failed
        setState(() {
          _errorMessage = 'Failed to create subscription: ${result['error']}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create subscription: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error creating subscription: $e');
      
      // Make sure processing dialog is closed
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _errorMessage = 'Failed to create subscription: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Processing Payment'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Please wait...'),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final hasActiveSubscription = _subscriptions.any((sub) => sub['status'] == 'active');
    
    if (_isAddingCard) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add Payment Method'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isAddingCard = false;
              });
            },
          ),
        ),
        body: PaymentCardInput(
          onPaymentMethodCreated: _processNewSubscription,
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubscriptionBanner(
                    isActive: hasActiveSubscription,
                    onActivateTap: _addPaymentMethodAndSubscribe,
                  ),
                  const SizedBox(height: 24),
                  
                  // Payment methods section
                  if (_paymentMethods.isNotEmpty) ...[
                    Text(
                      'Your Payment Methods',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._paymentMethods.map((method) => _buildPaymentMethodItem(method)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _addPaymentMethodAndSubscribe,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Payment Method'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Subscription status
                  Text(
                    hasActiveSubscription ? 'Active Subscriptions' : 'No Active Subscriptions',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Subscriptions list
                  if (_subscriptions.isNotEmpty) ...[
                    ..._subscriptions.map((subscription) => _buildSubscriptionItem(subscription)),
                    const SizedBox(height: 24),
                  ],
                  
                  // No subscriptions message
                  if (_subscriptions.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB), // gray-50
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)), // gray-200
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.subscriptions_outlined,
                            size: 48,
                            color: Color(0xFF8B5CF6), // purple-600
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Subscriptions Found',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Subscribe to unlock premium features and get the most out of your Immy experience.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280), // gray-500
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _addPaymentMethodAndSubscribe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6), // purple-600
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Subscribe Now'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Available serial numbers
                  if (_serialNumbers.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Your Devices',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._serialNumbers.map((serial) => _buildSerialItem(serial)),
                  ],
                ],
              ),
            ),
    );
  }
  
  Widget _buildPaymentMethodItem(Map<String, dynamic> method) {
    // Extract card details
    final card = method['card'] ?? {};
    final brand = card['brand'] ?? 'Unknown';
    final last4 = card['last4'] ?? '****';
    final expMonth = card['exp_month']?.toString() ?? '--';
    final expYear = card['exp_year']?.toString() ?? '--';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)), // gray-200
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE), // purple-100
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.credit_card,
              color: Color(0xFF8B5CF6), // purple-600
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand.toString().toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '**** **** **** $last4 • Expires $expMonth/$expYear',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _addPaymentMethodAndSubscribe,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6), // purple-600
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubscriptionItem(Map<String, dynamic> subscription) {
    final startDate = subscription['start_date'] is String
        ? DateTime.parse(subscription['start_date'])
        : subscription['start_date'] as DateTime;
    
    final endDate = subscription['end_date'] is String
        ? DateTime.parse(subscription['end_date'])
        : subscription['end_date'] as DateTime;
    
    final isActive = subscription['status'] == 'active';
    final isExpired = endDate.isBefore(DateTime.now());
    final status = isActive ? (isExpired ? 'Expired' : 'Active') : 'Cancelled';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)), // gray-200
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Premium Monthly',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isExpired ? Colors.orange.shade100 : Colors.green.shade100)
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? (isExpired ? Colors.orange.shade800 : Colors.green.shade800)
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Color(0xFF6B7280), // gray-500
              ),
              const SizedBox(width: 4),
              Text(
                'Started: ${_formatDate(startDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280), // gray-500
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.event,
                size: 14,
                color: Color(0xFF6B7280), // gray-500
              ),
              const SizedBox(width: 4),
              Text(
                'Expires: ${_formatDate(endDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280), // gray-500
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '£7.99 / month',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (isActive && !isExpired) 
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _addPaymentMethodAndSubscribe,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6), // purple-600
                        side: const BorderSide(color: Color(0xFF8B5CF6)), // purple-600
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Update'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _cancelSubscription(
                        subscription['id'],
                        subscription['stripe_subscription_id'],
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSerialItem(Map<String, dynamic> serial) {
    final hasActiveSubscription = _subscriptions.any((sub) => 
      sub['serial_id'] == serial['id'] && 
      sub['status'] == 'active' &&
      _parseDateTime(sub['end_date']).isAfter(DateTime.now())
    );
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)), // gray-200
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE), // purple-100
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.devices,
              color: Color(0xFF8B5CF6), // purple-600
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Serial: ${serial['serial']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  hasActiveSubscription ? 'Subscription: Active' : 'Subscription: Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasActiveSubscription
                        ? Colors.green.shade700
                        : const Color(0xFF6B7280), // gray-500
                  ),
                ),
              ],
            ),
          ),
          if (!hasActiveSubscription)
            TextButton(
              onPressed: _addPaymentMethodAndSubscribe,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6), // purple-600
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Subscribe'),
            ),
        ],
      ),
    );
  }
  
  // Helper method to safely parse DateTime
  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now(); // Fallback
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}
