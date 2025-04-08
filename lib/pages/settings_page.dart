import 'package:flutter/material.dart';
import '../widgets/subscription_banner.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _bedtimeModeEnabled = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SubscriptionBanner(isActive: true),
            const SizedBox(height: 24),
            
            // Learning Settings Section
            const Text(
              'Learning Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Customize Immy\'s learning approach',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280), // gray-500
              ),
            ),
            const SizedBox(height: 16),
            
            // Learning Level
            _buildSettingsItem(
              'Learning Level',
              'Age 5-7 (Kindergarten)',
              const Color(0xFFE0E7FF), // indigo-100
              const Color(0xFF4F46E5), // indigo-600
              Icons.psychology,
            ),
            
            // Child's Interests
            _buildSettingsItem(
              'Child\'s Interests',
              'Space, Animals, Music',
              const Color(0xFFFCE7F3), // pink-100
              const Color(0xFFDB2777), // pink-600
              Icons.favorite,
            ),
            
            // Bedtime Mode
            _buildSettingsItemWithSwitch(
              'Bedtime Mode',
              '7:30 PM - 7:00 AM',
              const Color(0xFFDDEEFD), // blue-100
              const Color(0xFF2563EB), // blue-600
              Icons.nightlight_round,
            ),
            
            const SizedBox(height: 24),
            
            // Privacy & Security Section
            const Text(
              'Privacy & Security',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Manage data and privacy settings',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280), // gray-500
              ),
            ),
            const SizedBox(height: 16),
            
            // Data Privacy
            _buildSettingsItem(
              'Data Privacy',
              'Manage conversation data',
              const Color(0xFFDCFCE7), // green-100
              const Color(0xFF16A34A), // green-600
              Icons.shield,
            ),
            
            // Notifications
            _buildSettingsItem(
              'Notifications',
              'Insights and updates',
              const Color(0xFFFEF3C7), // amber-100
              const Color(0xFFD97706), // amber-600
              Icons.notifications,
            ),
            
            const SizedBox(height: 24),
            
            // Help & Support
            const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFE5E7EB), // gray-200
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Help & Support',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Sign Out
            const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFFEE2E2), // red-100
                  child: Icon(
                    Icons.logout,
                    size: 16,
                    color: Color(0xFFEF4444), // red-500
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFFEF4444), // red-500
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    String subtitle,
    Color bgColor,
    Color iconColor,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: bgColor,
            child: Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: Color(0xFF9CA3AF), // gray-400
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItemWithSwitch(
    String title,
    String subtitle,
    Color bgColor,
    Color iconColor,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: bgColor,
            child: Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _bedtimeModeEnabled,
            onChanged: (value) {
              setState(() {
                _bedtimeModeEnabled = value;
              });
            },
            activeColor: const Color(0xFF8B5CF6), // purple-600
          ),
        ],
      ),
    );
  }
}
