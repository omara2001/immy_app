import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:io'; // Add this import for File and Directory
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/serial_number.dart';
import '../services/auth_service.dart';
import '../services/users_auth_service.dart' as user_auth;
import '../utils/password_util.dart'; // Make sure this path is correct
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'backend_api_service.dart';

// Conditional imports

class SerialService {
  static const String _userProfilesKey = 'user_profiles';
  static const String _serialNumbersKey = 'serial_numbers';
  final Uuid _uuid = const Uuid();
  final AuthService _authService = AuthService();
  final user_auth.AuthService _userAuthService = user_auth.AuthService();
  
  // Check if the current user is an admin before performing admin-only operations
  Future<void> _checkAdminAccess() async {
    // First check user auth service
    final isUserAdmin = await _userAuthService.isCurrentUserAdmin();
    
    // Then check admin auth service
    final isAdminServiceAdmin = await _authService.isCurrentUserAdmin();
    
    // If either returns true, allow access
    if (!isUserAdmin && !isAdminServiceAdmin) {
      throw Exception('Access denied: Admin privileges required');
    }
  }
  
  // Initialize with sample data for testing
  Future<void> initWithSampleData() async {
    // This is an admin-only operation after the first setup
    try {
      await _checkAdminAccess();
    } catch (e) {
      // Ignore the error for initial setup
      debugPrint("Ignoring admin check for initial setup: $e");
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have data
    final hasProfiles = prefs.containsKey(_userProfilesKey);
    final hasSerials = prefs.containsKey(_serialNumbersKey);
    
    if (!hasProfiles || !hasSerials) {
      // Create sample users with password hashes
      final users = [
        UserProfile(
          id: _uuid.v4(),
          name: 'Administrator',
          email: 'administrator', // Simple username as requested
          isAdmin: true, // Set this user as admin
          passwordHash: PasswordUtil.hashPassword('admin'), // Simple password as requested
        ),
        UserProfile(
          id: _uuid.v4(),
          name: 'Regular User',
          email: 'user@example.com',
          isAdmin: false,
          passwordHash: PasswordUtil.hashPassword('user123'),
        ),
      ];
    
      // Save users
      await prefs.setString(_userProfilesKey, jsonEncode(users.map((u) => u.toJson()).toList()));
    
      // Generate sample serials
      final serials = <SerialNumber>[];
      for (int i = 0; i < 5; i++) {
        final serial = generateSerialNumber();
        final qrCodePath = await generateQrCode(serial);
      
        serials.add(SerialNumber(
          id: _uuid.v4(),
          serial: serial,
          qrCodePath: qrCodePath,
          // Assign the first two serials to our sample users
          assignedToUserId: i < 2 ? users[i].id : null,
          status: 'active',
        ));
      }
    
      // Save serials
      await prefs.setString(_serialNumbersKey, jsonEncode(serials.map((s) => s.toJson()).toList()));
      
      // Also sync the admin user with the user auth service
      await _syncAdminUser();
    }
  }
  
  // Sync admin user between auth services
  Future<void> _syncAdminUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_userProfilesKey);
      
      if (profilesJson != null) {
        final List<dynamic> decoded = jsonDecode(profilesJson);
        final profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
        
        // Find admin user
        final adminUser = profiles.firstWhere(
          (profile) => profile.email == 'administrator' && profile.isAdmin,
          orElse: () => UserProfile(
            id: _uuid.v4(),
            name: 'Administrator',
            email: 'administrator',
            isAdmin: true,
            passwordHash: PasswordUtil.hashPassword('admin'),
          ),
        );
        
        // Create admin user in user auth service
        await _userAuthService.login('administrator', 'admin');
        debugPrint("Synced admin user with user auth service");
      }
    } catch (e) {
      debugPrint("Error syncing admin user: $e");
    }
  }
  
  // Generate a new serial number in the format IMMY-2025-XXXXXX
  String generateSerialNumber() {
    final random = Random();
    final digits = List.generate(6, (_) => random.nextInt(10)).join();
    return 'IMMY-2025-$digits';
  }
  
  // Generate a QR code for a serial number and save it to local storage
  Future<String> generateQrCode(String serial) async {
    // Create QR code widget
    final qrCode = QrImageView(
      data: serial,
      version: QrVersions.auto,
      size: 200.0,
      backgroundColor: Colors.white,
    );
    
    // Handle web vs mobile
    if (kIsWeb) {
      // For web, just return a placeholder URL - no need to download
      return 'qr_$serial.png';
    } else {
      // On mobile, save the QR code to the local file system
      try {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/qr_codes';
        await Directory(path).create(recursive: true);
        
        final filePath = '$path/qr_$serial.png';
        
        // Convert the QR widget to image bytes and save to file
        final qrImage = await _getQrImageBytes(qrCode);
        final file = File(filePath);
        await file.writeAsBytes(qrImage);
        
        return filePath;
      } catch (e) {
        // If there's an error saving the file, return a placeholder
        debugPrint('Error saving QR code: $e');
        return 'qr_$serial.png';
      }
    }
  }

  // Helper function to generate the image bytes for the QR code
  Future<Uint8List> _getQrImageBytes(QrImageView qrCode) async {
    try {
      final boundary = await _createQrBoundary(qrCode);
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate QR code image');
      return byteData.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to generate QR code: $e');
    }
  }

  Future<RenderRepaintBoundary> _createQrBoundary(QrImageView qrCode) async {
    final key = GlobalKey();
    final RepaintBoundary boundary = RepaintBoundary(
      key: key,
      child: qrCode,
    );

    // Create a temporary widget to render the QR code
    final widget = MaterialApp(
      home: Scaffold(body: boundary),
    );

    final BuildContext context = await _createTemporaryContext(widget);
    await Future.delayed(const Duration(milliseconds: 100)); // Allow widget to render
    
    final RenderRepaintBoundary renderObject = 
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return renderObject;
  }

  Future<BuildContext> _createTemporaryContext(Widget widget) async {
    final completer = Completer<BuildContext>();
    
    runApp(Builder(builder: (ctx) {
      completer.complete(ctx);
      return widget;
    }));
    
    return completer.future;
  }
  
  // Get registered users from the database
  Future<List<UserProfile>> getAllUsers() async {
    try {
      // Try to fetch users from the database first
      final dbUsers = await BackendApiService.getAllUsers();
      
      // Convert to UserProfile objects
      final userProfiles = dbUsers.map((user) => UserProfile(
        id: user['id'].toString(),
        name: user['name'] ?? 'Unknown',
        email: user['email'] ?? 'unknown@example.com',
        isAdmin: user['is_admin'] == 1 || user['is_admin'] == true,
      )).toList();
      
      // If we have users from the database, return them
      if (userProfiles.isNotEmpty) {
        return userProfiles;
      }
      
      // Fall back to local storage if no users found in database
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_userProfilesKey);
      
      if (profilesJson != null) {
        final List<dynamic> decoded = jsonDecode(profilesJson);
        return decoded.map((json) => UserProfile.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error fetching users from database: $e');
      
      // Fall back to local storage
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_userProfilesKey);
      
      if (profilesJson != null) {
        final List<dynamic> decoded = jsonDecode(profilesJson);
        return decoded.map((json) => UserProfile.fromJson(json)).toList();
      }
      
      return [];
    }
  }
  
  // Get all serial numbers from database with fallback to local storage
  Future<List<SerialNumber>> getSerialList() async {
    try {
      // Try to fetch from database first
      final dbSerials = await BackendApiService.executeQuery(
        'SELECT s.id, s.serial, s.user_id as assignedToUserId, s.status FROM SerialNumbers s'
      );
      
      // If we have data from the database, convert and return it
      if (dbSerials.isNotEmpty) {
        final List<SerialNumber> serials = [];
        for (final serial in dbSerials) {
          final qrCodePath = await generateQrCode(serial['serial']);
          serials.add(SerialNumber(
            id: serial['id'].toString(),
            serial: serial['serial'],
            qrCodePath: qrCodePath,
            assignedToUserId: serial['assignedToUserId']?.toString(),
            status: serial['status'] ?? 'active',
          ));
        }
        return serials;
      }
      
      // Fall back to local storage
      final prefs = await SharedPreferences.getInstance();
      final serialsJson = prefs.getString(_serialNumbersKey);
      
      if (serialsJson != null) {
        final List<dynamic> decoded = jsonDecode(serialsJson);
        return decoded.map((json) => SerialNumber.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error fetching serials from database: $e');
      
      // Fall back to local storage
      final prefs = await SharedPreferences.getInstance();
      final serialsJson = prefs.getString(_serialNumbersKey);
      
      if (serialsJson != null) {
        final List<dynamic> decoded = jsonDecode(serialsJson);
        return decoded.map((json) => SerialNumber.fromJson(json)).toList();
      }
      
      return [];
    }
  }
  
  // Get serial number by user email from database
  Future<SerialNumber?> getUserSerial(String email) async {
    try {
      // Try to find user in database first
      final dbUser = await BackendApiService.getUserByEmail(email);
      
      if (dbUser != null) {
        final userId = dbUser['id'];
        final dbSerials = await BackendApiService.getQRCodesForUser(userId);
        
        if (dbSerials.isNotEmpty) {
          final serial = dbSerials.first;
          final qrCodePath = await generateQrCode(serial['serial']);
          
          return SerialNumber(
            id: serial['id'].toString(),
            serial: serial['serial'],
            qrCodePath: qrCodePath,
            assignedToUserId: userId.toString(),
            status: serial['status'] ?? 'active',
          );
        }
      }
      
      // Fall back to local storage
      final users = await _getUserProfiles();
      final user = users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('User not found: $email'),
      );
      
      final serials = await _getSerialNumbers();
      final serial = serials.firstWhere(
        (s) => s.assignedToUserId == user.id,
        orElse: () => throw Exception('No serial number assigned to this user'),
      );
      
      return serial;
    } catch (e) {
      debugPrint('Error looking up user serial: $e');
      throw Exception('Could not find serial number for user $email');
    }
  }
  
  // Generate new serial numbers and save to database
  Future<void> generateSerials(int count) async {
    await _checkAdminAccess();
    
    try {
      final newSerials = <SerialNumber>[];
      
      for (int i = 0; i < count; i++) {
        final serial = generateSerialNumber();
        final qrCodePath = await generateQrCode(serial);
        
        // Insert into database
        await BackendApiService.executeQuery(
          'INSERT INTO SerialNumbers (serial, status) VALUES (?, ?)',
          [serial, 'active']
        );
        
        newSerials.add(SerialNumber(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}_$i',
          serial: serial,
          qrCodePath: qrCodePath,
          status: 'active',
        ));
      }
      
      // Also update local storage
      final serials = await _getSerialNumbers();
      serials.addAll(newSerials);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serialNumbersKey, jsonEncode(serials.map((s) => s.toJson()).toList()));
      
    } catch (e) {
      debugPrint('Error generating serials: $e');
      throw Exception('Failed to generate serial numbers: $e');
    }
  }
  
  // Assign a serial number to a user in the database
  Future<void> assignSerialToUser(UserProfile user, SerialNumber serial) async {
    await _checkAdminAccess();
    
    try {
      // Try to update in database first
      await BackendApiService.assignQRCode(int.parse(user.id), serial.serial);
      
      // Also update in local storage
      final serials = await _getSerialNumbers();
      final index = serials.indexWhere((s) => s.id == serial.id);
      
      if (index >= 0) {
        serials[index].assignedToUserId = user.id;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_serialNumbersKey, jsonEncode(serials.map((s) => s.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('Error assigning serial to user: $e');
      throw Exception('Failed to assign serial number: $e');
    }
  }
  
  // Replace a user's serial number with a new one
  Future<void> replaceSerial(UserProfile user, SerialNumber newSerial) async {
    await _checkAdminAccess();
    
    try {
      // Get user's current serials from database
      final dbSerials = await BackendApiService.getQRCodesForUser(int.parse(user.id));
      
      if (dbSerials.isNotEmpty) {
        // Update existing serials to inactive
        for (final serial in dbSerials) {
          await BackendApiService.executeQuery(
            'UPDATE SerialNumbers SET status = ? WHERE id = ?',
            ['inactive', serial['id']]
          );
        }
      }
      
      // Assign new serial
      await BackendApiService.assignQRCode(int.parse(user.id), newSerial.serial);
      
      // Also update in local storage
      final serials = await _getSerialNumbers();
      
      // Update any existing serials for this user to be unassigned
      for (final s in serials) {
        if (s.assignedToUserId == user.id) {
          s.assignedToUserId = null;
        }
      }
      
      // Assign the new serial
      final index = serials.indexWhere((s) => s.id == newSerial.id);
      if (index >= 0) {
        serials[index].assignedToUserId = user.id;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_serialNumbersKey, jsonEncode(serials.map((s) => s.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('Error replacing serial: $e');
      throw Exception('Failed to replace serial number: $e');
    }
  }
  
  // Helper method to get user profiles from local storage
  Future<List<UserProfile>> _getUserProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_userProfilesKey);
    
    if (profilesJson == null) {
      return [];
    }
    
    final List<dynamic> decoded = jsonDecode(profilesJson);
    return decoded.map((json) => UserProfile.fromJson(json)).toList();
  }
  
  // Helper method to get serial numbers from local storage
  Future<List<SerialNumber>> _getSerialNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final serialsJson = prefs.getString(_serialNumbersKey);
    
    if (serialsJson == null) {
      return [];
    }
    
    final List<dynamic> decoded = jsonDecode(serialsJson);
    return decoded.map((json) => SerialNumber.fromJson(json)).toList();
  }
}