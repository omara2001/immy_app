import 'package:flutter/material.dart';

class SubscriptionBanner extends StatelessWidget {
  final bool isActive;

  const SubscriptionBanner({
    super.key,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF5E8FF) : const Color(0xFFFEF3C7), // light purple or amber-100
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF8B5CF6).withOpacity(0.2) : const Color(0xFFFDE68A), // purple-200 or amber-200
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star,
              size: 16,
              color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFFD97706), // purple-600 or amber-600
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Subscription Active' : 'Subscription Inactive',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFFD97706), // purple-600 or amber-600
                  ),
                ),
                Text(
                  isActive
                      ? 'Your Immy is fully activated! Next payment: June 15, 2023'
                      : "Reactivate your subscription to unlock Immy's full potential.",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
              ],
            ),
          ),
          if (!isActive)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6), // purple-600
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Activate',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}

