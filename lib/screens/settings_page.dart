import 'package:flutter/material.dart';
import '../widgets/subscription_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _bedtimeModeEnabled = true;
  String _learningLevel = 'Age 5-7 (Kindergarten)';
  String _childInterests = 'Space, Animals, Music';
  String _bedtimeHours = '7:30 PM - 7:00 AM';
  bool _isLoading = true;
  
  // This would come from your authentication system in a real app
  final String _userEmail = 'emma@example.com';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bedtimeModeEnabled = prefs.getBool('bedtimeModeEnabled') ?? true;
      _learningLevel = prefs.getString('learningLevel') ?? 'Age 5-7 (Kindergarten)';
      _childInterests = prefs.getString('childInterests') ?? 'Space, Animals, Music';
      _bedtimeHours = prefs.getString('bedtimeHours') ?? '7:30 PM - 7:00 AM';
      _isLoading = false;
    });
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bedtimeModeEnabled', _bedtimeModeEnabled);
    await prefs.setString('learningLevel', _learningLevel);
    await prefs.setString('childInterests', _childInterests);
    await prefs.setString('bedtimeHours', _bedtimeHours);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  // Show dialog to edit learning level
  void _showLearningLevelDialog() {
    final List<String> levels = [
      'Age 3-4 (Preschool)',
      'Age 5-7 (Kindergarten)',
      'Age 8-10 (Elementary)',
      'Age 11-13 (Middle School)'
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Learning Level'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: levels.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(levels[index]),
                onTap: () {
                  setState(() {
                    _learningLevel = levels[index];
                  });
                  _saveSettings();
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Show dialog to edit child's interests
  void _showInterestsDialog() {
    final TextEditingController controller = TextEditingController(text: _childInterests);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Child\'s Interests'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter interests separated by commas',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _childInterests = controller.text;
              });
              _saveSettings();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Show dialog to edit bedtime hours
  void _showBedtimeDialog() {
    final TextEditingController controller = TextEditingController(text: _bedtimeHours);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bedtime Hours'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. 7:30 PM - 7:00 AM',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _bedtimeHours = controller.text;
              });
              _saveSettings();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Show data privacy settings
  void _showDataPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Privacy Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage how your data is stored and used:'),
            SizedBox(height: 16),
            Text('• Conversation history is stored locally on your device'),
            Text('• Learning progress is synced with your account'),
            Text('• Usage analytics help us improve the app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Show confirmation dialog for data deletion
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete All Data?'),
                  content: const Text('This will erase all conversation history and learning progress. This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Implement data deletion logic here
                        Navigator.pop(context); // Close confirmation dialog
                        Navigator.pop(context); // Close privacy settings dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All data has been deleted')),
                        );
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Delete All Data', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Show notification settings
  void _showNotificationSettings() {
    bool dailyInsights = true;
    bool weeklyReports = true;
    bool appUpdates = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Notification Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Daily Insights'),
                  subtitle: const Text('Learning progress and tips'),
                  value: dailyInsights,
                  onChanged: (value) {
                    setDialogState(() {
                      dailyInsights = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Weekly Reports'),
                  subtitle: const Text('Summary of learning activity'),
                  value: weeklyReports,
                  onChanged: (value) {
                    setDialogState(() {
                      weeklyReports = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('App Updates'),
                  subtitle: const Text('New features and improvements'),
                  value: appUpdates,
                  onChanged: (value) {
                    setDialogState(() {
                      appUpdates = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Save notification preferences
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification settings updated')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show help and support dialog
  void _showHelpAndSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help with Immy?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSupportOption(
              'FAQs',
              'Browse frequently asked questions',
              Icons.help_outline,
              () {
                Navigator.pop(context);
                // Navigate to FAQs page
              },
            ),
            _buildSupportOption(
              'Contact Support',
              'Email our support team',
              Icons.email_outlined,
              () {
                Navigator.pop(context);
                // Open email client or support form
              },
            ),
            _buildSupportOption(
              'Tutorial',
              'Learn how to use Immy',
              Icons.play_circle_outline,
              () {
                Navigator.pop(context);
                // Show app tutorial
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportOption(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle sign out
  void _signOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to the login page after signing out
              Navigator.pushReplacementNamed(context, '/login');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out successfully')),
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
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
            InkWell(
              onTap: _showLearningLevelDialog,
              child: _buildSettingsItem(
                'Learning Level',
                _learningLevel,
                const Color(0xFFE0E7FF), // indigo-100
                const Color(0xFF4F46E5), // indigo-600
                Icons.psychology,
              ),
            ),
            
            // Child's Interests
            InkWell(
              onTap: _showInterestsDialog,
              child: _buildSettingsItem(
                'Child\'s Interests',
                _childInterests,
                const Color(0xFFFCE7F3), // pink-100
                const Color(0xFFDB2777), // pink-600
                Icons.favorite,
              ),
            ),
            
            // Bedtime Mode
            InkWell(
              onTap: _showBedtimeDialog,
              child: _buildSettingsItemWithSwitch(
                'Bedtime Mode',
                _bedtimeHours,
                const Color(0xFFDDEEFD), // blue-100
                const Color(0xFF2563EB), // blue-600
                Icons.nightlight_round,
              ),
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
            InkWell(
              onTap: _showDataPrivacySettings,
              child: _buildSettingsItem(
                'Data Privacy',
                'Manage conversation data',
                const Color(0xFFDCFCE7), // green-100
                const Color(0xFF16A34A), // green-600
                Icons.shield,
              ),
            ),
            
            // Notifications
            InkWell(
              onTap: _showNotificationSettings,
              child: _buildSettingsItem(
                'Notifications',
                'Insights and updates',
                const Color(0xFFFEF3C7), // amber-100
                const Color(0xFFD97706), // amber-600
                Icons.notifications,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Help & Support
            InkWell(
              onTap: _showHelpAndSupport,
              child: const Row(
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
            ),
            
            const SizedBox(height: 16),
            
            // Sign Out
            InkWell(
              onTap: _signOut,
              child: const Row(
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
              _saveSettings();
            },
            activeColor: const Color(0xFF8B5CF6), // purple-600
          ),
        ],
      ),
    );
  }
}