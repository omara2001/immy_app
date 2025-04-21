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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get user's subscriptions
      _subscriptions = await BackendApiService.getUserSubscriptions(widget.userId);
      
      // Get user's serial numbers
      final serials = await BackendApiService.executeQuery(
        'SELECT * FROM SerialNumbers WHERE user_id = ?',
        [widget.userId]
      );
      
      setState(() {
        _serialNumbers = serials;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load subscription data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _cancelSubscription(int subscriptionId, String? stripeSubscriptionId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Cancel subscription in Stripe if available
      if (stripeSubscriptionId != null) {
        await StripeService.cancelSubscription(
          subscriptionId: stripeSubscriptionId,
        );
      }
      
      // Update subscription status in database
      await BackendApiService.executeQuery(
        'UPDATE Subscriptions SET status = ? WHERE id = ?',
        ['canceled', subscriptionId]
      );
      
      // Reload data
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription canceled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to cancel subscription: $e';
      });
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
                                Navigator.pushNamed(
                                  context,
                                  '/payment',
                                  arguments: {
                                    'userId': widget.userId,
                                    'serialId': _serialNumbers.first['id'],
                                  },
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
    final status = isActive ? (isExpired ? 'Expired' : 'Active') : 'Canceled';
    
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
                Navigator.pushNamed(
                  context,
                  '/payment',
                  arguments: {
                    'userId': widget.userId,
                    'serialId': serial['id'],
                  },
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
