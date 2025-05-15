import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;
import '../services/backend_api_service.dart';
import '../main.dart'; // Import to access navigatorKey

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Subscription expiry notification IDs (100-199)
  static const int subscriptionExpiryBaseId = 100;
  static const int maxExpiryNotifications = 12; // Send for 24 hours (every 2 hours)

  // Update alert notification ID (200)
  static const int updateAlertId = 200;

  // Initialize notification service
  Future<void> init() async {
    try {
      tz_init.initializeTimeZones();

      // Define notification channels for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      // Create the Android notification channel
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false, // We'll request permissions separately
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          debugPrint('Notification tapped: ${response.payload}');
          _handleNotificationTap(response.payload);
        },
      );

      // Request permissions after initialization
      await requestNotificationPermissions();

      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  // Add new method to request permissions
  Future<bool> requestNotificationPermissions() async {
    try {
      // For iOS
      final ios = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      // For Android
      final android = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
           ?.requestNotificationsPermission();

      return ios ?? android ?? false;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  // Add method to check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      // For Android
      final androidEnabled = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();

      // For iOS we assume true if the app is running (iOS handles permissions differently)
      return androidEnabled ?? true;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return false;
    }
  }

  // Handle notification tap
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    debugPrint('Notification payload: $payload');

    // Parse the payload
    final parts = payload.split(':');
    if (parts.length < 2) return;

    final type = parts[0];
    final userId = parts[1];

    // Use the global navigator key to navigate from anywhere
    switch (type) {
      case 'subscription_expired':
        // Navigate to subscription page
        navigatorKey.currentState?.pushNamed('/subscription', arguments: {'userId': userId});
        break;
      case 'update_alert':
        // Navigate to insights page
        navigatorKey.currentState?.pushNamed('/home', arguments: {'initialTab': 1});
        break;
      case 'test_notification':
        // Do nothing special for test notifications
        break;
    }
  }

  // Schedule subscription expiry notifications (every 2 hours for 24 hours)
  Future<void> scheduleSubscriptionExpiryNotifications(String userId) async {
    // Cancel any existing expiry notifications first
    await cancelSubscriptionExpiryNotifications();

    const String title = 'Subscription Expired';
    const String body = 'Your subscription has expired. Please renew to continue accessing all features.';

    // Schedule notifications every 2 hours for 24 hours
    for (int i = 0; i < maxExpiryNotifications; i++) {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(hours: 2 * (i + 1)));

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        subscriptionExpiryBaseId + i,
        title,
        body,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'subscription_expiry_channel',
            'Subscription Expiry',
            channelDescription: 'Notifications about subscription expiry',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF8B5CF6),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'subscription_expired:$userId',
      );
    }
  }

  // Cancel all subscription expiry notifications
  Future<void> cancelSubscriptionExpiryNotifications() async {
    for (int i = 0; i < maxExpiryNotifications; i++) {
      await _flutterLocalNotificationsPlugin.cancel(subscriptionExpiryBaseId + i);
    }
  }

  // Schedule daily update alert notification
  Future<void> scheduleUpdateAlertNotification(String userId, {TimeOfDay? preferredTime}) async {
    // Cancel any existing update alert notification
    await _flutterLocalNotificationsPlugin.cancel(updateAlertId);

    // Default to 6 PM if no preferred time is provided
    final preferredTimeOfDay = preferredTime ?? const TimeOfDay(hour: 18, minute: 0);

    // Calculate next occurrence of the preferred time
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      preferredTimeOfDay.hour,
      preferredTimeOfDay.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      updateAlertId,
      'Check Your Child\'s Progress',
      'Check out the latest updates and see how your child is progressing with Immy!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'update_alert_channel',
          'Progress Updates',
          channelDescription: 'Notifications about child\'s progress updates',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF8B5CF6),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'update_alert:$userId',
      matchDateTimeComponents: DateTimeComponents.time, // Repeat at the same time every day
    );
  }

  // Show immediate notification
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'immediate_channel',
          'Immediate Notifications',
          channelDescription: 'Immediate notifications that need attention',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF8B5CF6),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // Cancel update alert notification
  Future<void> cancelUpdateAlertNotifications() async {
    await _flutterLocalNotificationsPlugin.cancel(updateAlertId);
  }
}