import 'package:flutter/foundation.dart';
import 'backend_api_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class AdminDashboardService {
  static final _backendApi = BackendApiService();
  static const _uuid = Uuid();

  // Helper method to check if assigned_at column exists
  static Future<bool> _hasAssignedAtColumn() async {
    if (kIsWeb) return true; // Assume column exists on web
    
    try {
      final columns = await BackendApiService.executeQuery(
        "SHOW COLUMNS FROM SerialNumbers LIKE 'assigned_at'");
      return columns.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking column: $e');
      return false;
    }
  }

  // Get all registered users with their QR code status
  static Future<List<Map<String, dynamic>>> getRegisteredUsers() async {
    try {
      final hasAssignedAt = await _hasAssignedAtColumn();
      
      final query = hasAssignedAt ? '''
        SELECT 
          u.id, 
          u.name, 
          u.email, 
          u.created_at,
          s.serial as qr_code,
          s.status as qr_status,
          s.assigned_at as qr_assigned_date
        FROM Users u
        LEFT JOIN SerialNumbers s ON u.id = s.user_id AND s.status = 'assigned'
        ORDER BY u.created_at DESC
      ''' : '''
        SELECT 
          u.id, 
          u.name, 
          u.email, 
          u.created_at,
          s.serial as qr_code,
          s.status as qr_status,
          s.created_at as qr_assigned_date
        FROM Users u
        LEFT JOIN SerialNumbers s ON u.id = s.user_id AND s.status = 'assigned'
        ORDER BY u.created_at DESC
      ''';
      
      final results = await BackendApiService.executeQuery(query);
      return results;
    } catch (e) {
      debugPrint('Error fetching registered users: $e');
      throw Exception('Failed to fetch registered users: $e');
    }
  }

  // Search users by email or name
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final hasAssignedAt = await _hasAssignedAtColumn();
      
      final sqlQuery = hasAssignedAt ? '''
        SELECT 
          u.id, 
          u.name, 
          u.email, 
          u.created_at,
          s.serial as qr_code,
          s.status as qr_status,
          s.assigned_at as qr_assigned_date
        FROM Users u
        LEFT JOIN SerialNumbers s ON u.id = s.user_id
        WHERE u.email LIKE ? OR u.name LIKE ?
        ORDER BY u.created_at DESC
      ''' : '''
        SELECT 
          u.id, 
          u.name, 
          u.email, 
          u.created_at,
          s.serial as qr_code,
          s.status as qr_status,
          s.created_at as qr_assigned_date
        FROM Users u
        LEFT JOIN SerialNumbers s ON u.id = s.user_id
        WHERE u.email LIKE ? OR u.name LIKE ?
        ORDER BY u.created_at DESC
      ''';
      
      return await BackendApiService.executeQuery(
        sqlQuery, 
        [query, query].map((s) => '%$s%').toList()
      );
    } catch (e) {
      debugPrint('Error searching users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  // Generate new serial numbers
  static Future<List<String>> generateSerialNumbers(int count) async {
    try {
      final List<String> serials = [];

      for (int i = 0; i < count; i++) {
        final serial = 'IMMY-${DateTime.now().year}-${_generateRandomString(6)}';
        serials.add(serial);
      }

      // Insert all serials in a single batch
      await BackendApiService.createQRCodes(serials);

      return serials;
    } catch (e) {
      debugPrint('Error generating serial numbers: $e');
      throw Exception('Failed to generate serial numbers: $e');
    }
  }

  // Get all QR codes with their status
  static Future<List<Map<String, dynamic>>> getAllQRCodes() async {
    try {
      return await BackendApiService.getAllQRCodes();
    } catch (e) {
      debugPrint('Error fetching QR codes: $e');
      throw Exception('Failed to fetch QR codes: $e');
    }
  }

  // Get available QR codes
  static Future<List<Map<String, dynamic>>> getAvailableQRCodes() async {
    try {
      return await BackendApiService.getAvailableQRCodes();
    } catch (e) {
      debugPrint('Error fetching available QR codes: $e');
      throw Exception('Failed to fetch available QR codes: $e');
    }
  }

  // Assign QR code to user
  static Future<bool> assignQRCodeToUser(dynamic userId, String qrCode) async {
    try {
      // Convert userId to int if it's a string
      final int userIdInt = userId is String ? int.parse(userId) : userId;
      
      // First check if QR code is available
      final qrCodes = await BackendApiService.executeQuery('''
        SELECT id FROM SerialNumbers 
        WHERE serial = ? AND user_id IS NULL AND status = 'active'
      ''', [qrCode]);

      if (qrCodes.isEmpty) {
        throw Exception('QR code is not available for assignment');
      }

      // Get the QR code ID
      final qrCodeId = qrCodes.first['id'];

      // Assign the QR code to the user
      await BackendApiService.assignQRCodeToUser(qrCodeId, userIdInt);

      return true;
    } catch (e) {
      debugPrint('Error assigning QR code: $e');
      throw Exception('Failed to assign QR code: $e');
    }
  }

  // Get user's QR code details
  static Future<Map<String, dynamic>?> getUserQRCode(dynamic userId) async {
    try {
      // Convert userId to int if it's a string
      final int userIdInt = userId is String ? int.parse(userId) : userId;
      
      final hasAssignedAt = await _hasAssignedAtColumn();
      
      final query = hasAssignedAt ? '''
        SELECT 
          s.id,
          s.serial,
          s.status,
          s.created_at,
          s.assigned_at,
          u.name as assigned_to_name,
          u.email as assigned_to_email
        FROM SerialNumbers s
        LEFT JOIN Users u ON s.user_id = u.id
        WHERE s.user_id = ? AND s.status = 'assigned'
      ''' : '''
        SELECT 
          s.id,
          s.serial,
          s.status,
          s.created_at,
          u.name as assigned_to_name,
          u.email as assigned_to_email
        FROM SerialNumbers s
        LEFT JOIN Users u ON s.user_id = u.id
        WHERE s.user_id = ? AND s.status = 'assigned'
      ''';
      
      final results = await BackendApiService.executeQuery(query, [userIdInt]);

      return results.isEmpty ? null : results.first;
    } catch (e) {
      debugPrint('Error fetching user QR code: $e');
      throw Exception('Failed to fetch user QR code: $e');
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(dynamic userId, String name, String email) async {
    try {
      // Convert userId to int if it's a string
      final int userIdInt = userId is String ? int.parse(userId) : userId;
      
      await BackendApiService.executeQuery('''
        UPDATE Users 
        SET name = ?, email = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      ''', [name, email, userIdInt]);
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Set user admin status
  static Future<void> setUserAdmin(dynamic userId, bool isAdmin) async {
    try {
      // Convert userId to int if it's a string
      final int userIdInt = userId is String ? int.parse(userId) : userId;
      
      await BackendApiService.executeQuery('''
        UPDATE Users 
        SET is_admin = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      ''', [isAdmin ? 1 : 0, userIdInt]);
    } catch (e) {
      debugPrint('Error setting user admin status: $e');
      throw Exception('Failed to set user admin status: $e');
    }
  }

  // Change user password
  static Future<void> changeUserPassword(dynamic userId, String newPassword) async {
    try {
      // Convert userId to int if it's a string
      final int userIdInt = userId is String ? int.parse(userId) : userId;
      
      await BackendApiService.executeQuery('''
        UPDATE Users 
        SET password = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      ''', [newPassword, userIdInt]);
    } catch (e) {
      debugPrint('Error changing user password: $e');
      throw Exception('Failed to change user password: $e');
    }
  }

  // Helper method to generate random string for serial numbers
  static String _generateRandomString(int length) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }
} 