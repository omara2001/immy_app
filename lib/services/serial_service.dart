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

// Conditional imports
import 'dart:io' if (kIsWeb) 'dart:html' as html;

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
      print("Ignoring admin check for initial setup: $e");
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
        print("Synced admin user with user auth service");
      }
    } catch (e) {
      print("Error syncing admin user: $e");
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
        print('Error saving QR code: $e');
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
    late BuildContext context;
    final completer = Completer<BuildContext>();
    
    runApp(Builder(builder: (ctx) {
      context = ctx;
      completer.complete(ctx);
      return widget;
    }));
    
    return completer.future;
  }
  
  // Create a new user profile
  Future<UserProfile> createUserProfile(String name, String email, {bool isAdmin = false}) async {
    // Only admins can create admin users
    if (isAdmin) {
      await _checkAdminAccess();
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing profiles
    final List<UserProfile> profiles = await _getUserProfiles();
    
    // Check if email already exists
    if (profiles.any((profile) => profile.email == email)) {
      throw Exception('A user with this email already exists');
    }
    
    // Create new profile
    final newProfile = UserProfile(
      id: _uuid.v4(),
      name: name,
      email: email,
      isAdmin: isAdmin,
    );
    
    // Add to list and save
    profiles.add(newProfile);
    await prefs.setString(_userProfilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    
    return newProfile;
  }
  
  // Generate multiple serial numbers - admin only
  Future<List<SerialNumber>> generateSerials(int count) async {
    // This is an admin-only operation
    await _checkAdminAccess();
    
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing serials
    final List<SerialNumber> serials = await _getSerialNumbers();
    final List<SerialNumber> newSerials = [];
    
    // Generate new serials
    for (int i = 0; i < count; i++) {
      final serial = generateSerialNumber();
      final qrCodePath = await generateQrCode(serial);
      
      final newSerial = SerialNumber(
        id: _uuid.v4(),
        serial: serial,
        qrCodePath: qrCodePath,
      );
      
      newSerials.add(newSerial);
      serials.add(newSerial);
    }
    
    // Save updated list
    await prefs.setString(_serialNumbersKey, jsonEncode(serials.map((s) => s.toJson()).toList()));
    
    return newSerials;
  }
  
  // Assign a serial number to a user - admin only
  Future<void> assignSerialToUser(UserProfile user, SerialNumber serial) async {
    // This is an admin-only operation
    await _checkAdminAccess();
    
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing serials
    final List<SerialNumber> serials = await _getSerialNumbers();
    
    // Find and update the serial
    final index = serials.indexWhere((s) => s.id == serial.id);
    if (index == -1) {
      throw Exception('Serial number not found');
    }
    
    serials[index].assignedToUserId = user.id;
    
    // Save updated list
    await prefs.setString(_serialNumbersKey, jsonEncode(serials.map((s) => s.toJson()).toList()));
  }
  
  // Replace a user's serial number with a new one - admin only
  Future<void> replaceSerial(UserProfile user, SerialNumber newSerial) async {
    // This is an admin-only operation
    await _checkAdminAccess();
    
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing serials
    final List<SerialNumber> serials = await _getSerialNumbers();
    
    // Find old serial assigned to user
    final oldSerialIndex = serials.indexWhere((s) => s.assignedToUserId == user.id);
    if (oldSerialIndex != -1) {
      // Unassign old serial
      serials[oldSerialIndex].assignedToUserId = null;
    }
    
    // Find and assign new serial
    final newSerialIndex = serials.indexWhere((s) => s.id == newSerial.id);
    if (newSerialIndex == -1) {
      throw Exception('New serial number not found');
    }
    
    serials[newSerialIndex].assignedToUserId = user.id;
    
    // Save updated list
    await prefs.setString(_serialNumbersKey, jsonEncode(serials.map((s) => s.toJson()).toList()));
  }
  
  // Get all serial numbers - admin only
  Future<List<SerialNumber>> getSerialList() async {
    // This is an admin-only operation
    await _checkAdminAccess();
    
    return await _getSerialNumbers();
  }
  
  // Get unassigned serial numbers - admin only
  Future<List<SerialNumber>> getUnassignedSerials() async {
    // This is an admin-only operation
    await _checkAdminAccess();
    
    final serials = await _getSerialNumbers();
    return serials.where((serial) => serial.assignedToUserId == null).toList();
  }
  
  // Get a user's serial number - can be used by any user to get their own serial
  Future<SerialNumber?> getUserSerial(String email) async {
    final currentUser = await _authService.getCurrentUser();
    final profiles = await _getUserProfiles();
    final serials = await _getSerialNumbers();
    
    // Find user by email
    final userList = profiles.where((profile) => profile.email == email).toList();
    if (userList.isEmpty) {
      return null;
    }
    
    final user = userList.first;
    
    // If not admin and trying to access someone else's serial, deny access
    if (!(currentUser?.isAdmin ?? false) && currentUser?.email != email) {
      throw Exception('Access denied: You can only view your own serial number');
    }
    
    // Find serial assigned to user
    final userSerials = serials.where((serial) => serial.assignedToUserId == user.id).toList();
    if (userSerials.isEmpty) {
      return null;
    }
    
    return userSerials.first;
  }
  
  // Get all users - admin only
  Future<List<UserProfile>> getAllUsers() async {
    // This is an admin-only operation
    await _checkAdminAccess();
    
    return await _getUserProfiles();
  }
  
  // Helper method to get all user profiles from storage
  Future<List<UserProfile>> _getUserProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_userProfilesKey);
    
    if (profilesJson == null) {
      return [];
    }
    
    final List<dynamic> decoded = jsonDecode(profilesJson);
    return decoded.map((json) => UserProfile.fromJson(json)).toList();
  }
  
  // Helper method to get all serial numbers from storage
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
