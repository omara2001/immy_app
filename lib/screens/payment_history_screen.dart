import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/stripe_service.dart';
import '../services/payment_processor.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final int userId;
  
  const PaymentHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _payments = [];
  
  @override
  void initState() {
    super.initState();
    _loadPayments();
  }
  
  Future<void> _loadPayments() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('Loading payment history for user ${widget.userId}');
      
      // Get all payments for this user
      final results = await BackendApiService.executeQuery(
        'SELECT p.*, s.serial FROM Payments p '
        'LEFT JOIN SerialNumbers s ON p.serial_id = s.id '
        'WHERE p.user_id = ? '
        'ORDER BY p.created_at DESC',
        [widget.userId]
      );
      
      setState(() {
        _payments = results;
      });
      
      // If we have no payments, try to sync with Stripe
      if (_payments.isEmpty) {
        await _syncWithStripe();
      }
      
      print('Loaded ${_payments.length} payments');
    } catch (e) {
      print('Error loading payments: $e');
      setState(() {
        _errorMessage = 'Failed to load payment history: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _syncWithStripe() async {
    try {
      // Show a loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Use PaymentProcessor to sync with Stripe
      final result = await PaymentProcessor.syncWithStripe(widget.userId);
      
      // Reload payments after sync
      final results = await BackendApiService.executeQuery(
        'SELECT p.*, s.serial FROM Payments p '
        'LEFT JOIN SerialNumbers s ON p.serial_id = s.id '
        'WHERE p.user_id = ? '
        'ORDER BY p.created_at DESC',
        [widget.userId]
      );
      
      setState(() {
        _payments = results;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${result['payments']} payments and ${result['subscriptions']} subscriptions'),
          backgroundColor: Colors.green,
        ),
      );
      
      print('Synced payments with Stripe and reloaded ${_payments.length} payments');
    } catch (e) {
      print('Error syncing with Stripe: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error syncing with Stripe: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing with Stripe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync with Stripe',
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _syncWithStripe();
              setState(() {
                _isLoading = false;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty 
              ? _buildEmptyState()
              : _buildPaymentsList(),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.receipt_long,
            size: 64,
            color: Color(0xFFD1D5DB), // gray-300
          ),
          const SizedBox(height: 16),
          const Text(
            'No Payment History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your payment transactions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280), // gray-500
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6), // purple-600
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentsList() {
    return Column(
      children: [
        // Error message
        if (_errorMessage != null) ...[
          Container(
            margin: const EdgeInsets.all(16),
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
        ],
        
        // Payments list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _payments.length,
            itemBuilder: (context, index) {
              final payment = _payments[index];
              return _buildPaymentItem(payment);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final amount = payment['amount'] ?? 0.0;
    final currency = payment['currency'] ?? 'GBP';
    final status = payment['payment_status'] ?? 'unknown';
    
    // Format date using safe parsing
    final createdAt = _parseDateTime(payment['created_at']);
    final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    
    // Get serial number if available
    final serial = payment['serial'] ?? 'Unknown Device';
    
    // Determine icon and color based on status
    IconData statusIcon;
    Color statusColor;
    
    switch (status.toString().toLowerCase()) {
      case 'completed':
      case 'succeeded':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green.shade700;
        break;
      case 'pending':
      case 'processing':
        statusIcon = Icons.access_time;
        statusColor = Colors.orange.shade700;
        break;
      case 'failed':
      case 'canceled':
        statusIcon = Icons.cancel;
        statusColor = Colors.red.shade700;
        break;
      default:
        statusIcon = Icons.help_outline;
        statusColor = Colors.grey.shade700;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Container(
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
        title: const Text(
          'Subscription Payment',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Date: $formattedDate',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280), // gray-500
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Device: $serial',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280), // gray-500
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to safely parse DateTime
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