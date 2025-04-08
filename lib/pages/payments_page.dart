import 'package:flutter/material.dart';
import '../widgets/subscription_banner.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SubscriptionBanner(isActive: true),
            const SizedBox(height: 16),
            
            // Current Plan Section
            const Text(
              'Current Plan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Premium Monthly Subscription',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8B5CF6), // purple-600
              ),
            ),
            const SizedBox(height: 16),
            
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
            const Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF6B7280), // gray-500
                ),
                SizedBox(width: 8),
                Text(
                  'Next payment: June 15, 2023',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563), // gray-600
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Payment Method
            const Row(
              children: [
                Icon(
                  Icons.credit_card,
                  size: 16,
                  color: Color(0xFF6B7280), // gray-500
                ),
                SizedBox(width: 8),
                Text(
                  'Visa ending in 4242',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563), // gray-600
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Update Payment Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(
                    color: Color(0xFF8B5CF6), // purple-600
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Update Payment Method',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6), // purple-600
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Payment History Section
            const Text(
              'Payment History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            
            // Payment History Items
            _buildPaymentHistoryItem(
              'May 15, 2023',
              'Monthly Subscription',
              '£7.99',
            ),
            const Divider(
              height: 1,
              color: Color(0xFFF3F4F6), // gray-100
            ),
            _buildPaymentHistoryItem(
              'April 15, 2023',
              'Monthly Subscription',
              '£7.99',
            ),
            const Divider(
              height: 1,
              color: Color(0xFFF3F4F6), // gray-100
            ),
            _buildPaymentHistoryItem(
              'March 15, 2023',
              'Monthly Subscription',
              '£7.99',
            ),
            const SizedBox(height: 24),
            
            // Need Help Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7), // amber-100
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)), // amber-200
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFFDE68A), // amber-200
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFD97706), // amber-600
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Contact our support team for any billing-related questions or issues with your subscription.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280), // gray-500
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryItem(
    String date,
    String description,
    String amount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFDCFCE7), // green-100
            child: Icon(
              Icons.receipt,
              size: 16,
              color: Color(0xFF16A34A), // green-600
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

