import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart';
import 'backend_api_service.dart';
import '../models/user.dart';

class AdminDashboardService {
  static final _backendApi = BackendApiService();

  // Get all registered users with their QR code status
  static Future<List<Map<String, dynamic>>> getRegisteredUsers() async {
    try {
      final results = await BackendApiService.executeQuery('''
        SELECT 
          u.id, 
          u.name, 
          u.email, 
          u.created_at,
          s.serial as qr_code,
          s.status as qr_status
        FROM Users u
        LEFT JOIN SerialNumbers s ON u.id = s.user_id
        ORDER BY u.created_at DESC
      ''');

      return results;
    } catch (e) {
      debugPrint('Error fetching registered users: $e');
      throw Exception('Failed to fetch registered users: $e');
    }
  }

  // Search users by email
  static Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    try {
      return await BackendApiService.executeQuery('''
        SELECT 
          u.id, 
          u.name, 
          u.email, 
          u.created_at,
          s.serial as qr_code,
          s.status as qr_status
        FROM Users u
        LEFT JOIN SerialNumbers s ON u.id = s.user_id
        WHERE u.email LIKE ?
        ORDER BY u.created_at DESC
      ''', ['%$email%']);
    } catch (e) {
      debugPrint('Error searching users by email: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  // Assign QR code to user
  static Future<bool> assignQRCodeToUser(int userId, String qrCode) async {
    try {
      return await BackendApiService.assignQRCode(userId, qrCode);
    } catch (e) {
      debugPrint('Error assigning QR code: $e');
      throw Exception('Failed to assign QR code: $e');
    }
  }

  // Get user's QR code details
  static Future<Map<String, dynamic>?> getUserQRCode(int userId) async {
    try {
      final results = await BackendApiService.getQRCodesForUser(userId);
      return results.isEmpty ? null : results.first;
    } catch (e) {
      debugPrint('Error fetching user QR code: $e');
      throw Exception('Failed to fetch user QR code: $e');
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(int userId, String name, String email) async {
    try {
      await BackendApiService.updateUserProfile(userId, name, email);
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Set user admin status
  static Future<void> setUserAdmin(int userId, bool isAdmin) async {
    try {
      await BackendApiService.setUserAdmin(userId, isAdmin);
    } catch (e) {
      debugPrint('Error setting user admin status: $e');
      throw Exception('Failed to set user admin status: $e');
    }
  }

  // Change user password
  static Future<void> changeUserPassword(int userId, String newPassword) async {
    try {
      await BackendApiService.changeUserPassword(userId, newPassword);
    } catch (e) {
      debugPrint('Error changing user password: $e');
      throw Exception('Failed to change user password: $e');
    }
  }
} 