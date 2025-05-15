import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/subscription_monitor_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  final dynamic userId; // Accept both String and int

  const NotificationSettingsPage({
    super.key,
    required this.userId,
  });

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _subscriptionReminders = true;
  bool _progressUpdates = true;
  TimeOfDay _preferredTime = const TimeOfDay(hour: 18, minute: 0);
  late String _userIdStr;

  @override
  void initState() {
    super.initState();
    // Convert userId to string if it's an int
    _userIdStr = widget.userId is int ? widget.userId.toString() : widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Subscription Reminders'),
                    subtitle: const Text('Receive reminders when your subscription expires'),
                    value: _subscriptionReminders,
                    activeColor: const Color(0xFF8B5CF6),
                    onChanged: (value) {
                      setState(() {
                        _subscriptionReminders = value;
                      });
                      
                      if (!value) {
                        NotificationService().cancelSubscriptionExpiryNotifications();
                      } else {
                        SubscriptionMonitorService().startMonitoring(_userIdStr);
                      }
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Progress Updates'),
                    subtitle: const Text('Receive daily updates about your child\'s progress'),
                    value: _progressUpdates,
                    activeColor: const Color(0xFF8B5CF6),
                    onChanged: (value) {
                      setState(() {
                        _progressUpdates = value;
                      });
                      
                      if (!value) {
                        NotificationService().cancelUpdateAlertNotifications();
                      } else {
                        SubscriptionMonitorService().scheduleDailyUpdateNotification(
                          _userIdStr,
                          preferredTime: _preferredTime,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Timing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Preferred Time for Daily Updates'),
                    subtitle: Text(_preferredTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _preferredTime,
                      );
                      
                      if (picked != null && picked != _preferredTime) {
                        setState(() {
                          _preferredTime = picked;
                        });
                        
                        if (_progressUpdates) {
                          SubscriptionMonitorService().scheduleDailyUpdateNotification(
                            _userIdStr,
                            preferredTime: _preferredTime,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Test notifications
              NotificationService().showImmediateNotification(
                id: 999,
                title: 'Test Notification',
                body: 'This is a test notification to verify your settings.',
                payload: 'test_notification',
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test notification sent!'),
                  backgroundColor: Color(0xFF8B5CF6),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Test Notification'),
          ),
        ],
      ),
    );
  }
}


