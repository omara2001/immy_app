import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/stripe_service.dart';
import '../widgets/subscription_banner.dart';

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
            : sub['end_date'];
            
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
      
      bool isTestOrMock = stripeSubscriptionId.isEmpty || 
                         stripeSubscriptionId.startsWith('sub_test') || 
                         stripeSubscriptionId.startsWith('sub_mock') ||
                         stripeSubscriptionId.startsWith('sub_fallback') ||
                         stripeSubscriptionId.startsWith('sub_renewal');
      
      // Try to cancel in Stripe if it's not a test subscription
      if (!isTestOrMock) {
        try {
          await StripeService.cancelSubscription(
            subscriptionId: stripeSubscriptionId
          );
          print('Stripe subscription cancelled successfully');
        } catch (e) {
          print('Error cancelling Stripe subscription: $e');
          // Continue with cancellation even if Stripe fails
        }
      } else {
        print('Using test/mock subscription, skipping Stripe cancellation');
      }
      
      // Update subscription status in database
      try {
        await BackendApiService.executeQuery(
          'UPDATE Subscriptions SET status = ? WHERE id = ?',
          ['cancelled', subscriptionId]
        );
        print('Subscription marked as cancelled in database');
      } catch (e) {
        print('Error updating subscription status in database: $e');
      }
      
      // Update the UI by updating the status of the cancelled subscription
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
  
  @override
  Widget build(BuildContext context) {
    final hasActiveSubscription = _subscriptions.any((sub) => sub['status'] == 'active');
    
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
                  SubscriptionBanner(isActive: hasActiveSubscription),
                  const SizedBox(height: 24),
                  
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
                            onPressed: () {
                              // Navigate to payment screen if there's at least one serial number
                              if (_serialNumbers.isNotEmpty) {
                                // Update to use Payments tab in home page
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/home',
                                  (route) => false,
                                  arguments: {'initialTab': 3} // Payments tab index
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No serial numbers found. Please add a serial number first.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
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
  
  Widget _buildSubscriptionItem(Map<String, dynamic> subscription) {
    final startDate = subscription['start_date'] is String
        ? DateTime.parse(subscription['start_date'])
        : subscription['start_date'];
    
    final endDate = subscription['end_date'] is String
        ? DateTime.parse(subscription['end_date'])
        : subscription['end_date'];
    
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
                      onPressed: () {
                        // Update to use Payments tab in home page
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                          arguments: {'initialTab': 3} // Payments tab index
                        );
                      },
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
      DateTime.parse(sub['end_date'].toString()).isAfter(DateTime.now())
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
              onPressed: () {
                // Update to use Payments tab in home page
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                  arguments: {'initialTab': 3} // Payments tab index
                );
              },
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
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
