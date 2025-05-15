import 'dart:async';
import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/notification_service.dart';

class SubscriptionMonitorService {
  static final SubscriptionMonitorService _instance = SubscriptionMonitorService._internal();
  factory SubscriptionMonitorService() => _instance;
  SubscriptionMonitorService._internal();
  
  Timer? _subscriptionCheckTimer;
  final NotificationService _notificationService = NotificationService();
  
  // Start monitoring subscriptions - accepts both String and int
  void startMonitoring(dynamic userId) {
    // Convert userId to string if it's an int
    final String userIdStr = userId is int ? userId.toString() : userId;
    
    // Stop any existing timer
    stopMonitoring();
    
    // Check immediately
    _checkSubscriptionStatus(userIdStr);
    
    // Then check every hour
    _subscriptionCheckTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _checkSubscriptionStatus(userIdStr),
    );
  }
  
  // Stop monitoring subscriptions
  void stopMonitoring() {
    _subscriptionCheckTimer?.cancel();
    _subscriptionCheckTimer = null;
  }
  
  // Check subscription status
  Future<void> _checkSubscriptionStatus(String userId) async {
    try {
      // Convert string userId to integer
      final int userIdInt = int.parse(userId);
      
      // Get user's subscriptions
      final subscriptions = await BackendApiService.getUserSubscriptions(userIdInt);
      
      bool hasActiveSubscription = false;
      
      // Check if any subscription is active
      for (var subscription in subscriptions) {
        if (subscription['status'] == 'active') {
          final endDate = subscription['end_date'] is String 
              ? DateTime.parse(subscription['end_date'])
              : subscription['end_date'] as DateTime;
              
          if (endDate.isAfter(DateTime.now())) {
            hasActiveSubscription = true;
            break;
          }
        }
      }
      
      // If no active subscription, schedule expiry notifications
      if (!hasActiveSubscription && subscriptions.isNotEmpty) {
        await _notificationService.scheduleSubscriptionExpiryNotifications(userId);
      } else {
        // Cancel expiry notifications if subscription is active
        await _notificationService.cancelSubscriptionExpiryNotifications();
      }
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
    }
  }
  
  // Schedule daily update notifications - accepts both String and int
  Future<void> scheduleDailyUpdateNotification(dynamic userId, {TimeOfDay? preferredTime}) async {
    // Convert userId to string if it's an int
    final String userIdStr = userId is int ? userId.toString() : userId;
    
    await _notificationService.scheduleUpdateAlertNotification(userIdStr, preferredTime: preferredTime);
  }
}


