import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/serial_number.dart';

class SerialService {
  static const String _userProfilesKey = 'user_profiles';
  static const String _serialNumbersKey = 'serial_numbers';
  final Uuid _uuid = const Uuid();
  
  // Initialize with sample data for testing
  Future<void> initWithSampleData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have data
    final hasProfiles = prefs.containsKey(_userProfilesKey);
    final hasSerials = prefs.containsKey(_serialNumbersKey);
    
    if (!hasProfiles || !hasSerials) {
      // Create sample users
      final users = [
        UserProfile(
          id: _uuid.v4(),
          name: 'Emma',
          email: 'emma@example.com',
        ),
        UserProfile(
          id: _uuid.v4(),
          name: 'Oliver',
          email: 'oliver@example.com',
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
    
    // Convert to image and save to file
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/qr_codes';
    await Directory(path).create(recursive: true);
    
    final filePath = '$path/qr_$serial.png';
    
    // This is a simplified approach - in a real app, you'd need to render the QR widget to an image
    // For demonstration purposes, we'll just return the path where it would be saved
    
    return filePath;
  }
  
  // Create a new user profile
  Future<UserProfile> createUserProfile(String name, String email) async {
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
    );
    
    // Add to list and save
    profiles.add(newProfile);
    await prefs.setString(_userProfilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    
    return newProfile;
  }
  
  // Generate multiple serial numbers
  Future<List<SerialNumber>> generateSerials(int count) async {
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
  
  // Assign a serial number to a user
  Future<void> assignSerialToUser(UserProfile user, SerialNumber serial) async {
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
  
  // Replace a user's serial number with a new one
  Future<void> replaceSerial(UserProfile user, SerialNumber newSerial) async {
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
  
  // Get all serial numbers
  Future<List<SerialNumber>> getSerialList() async {
    return await _getSerialNumbers();
  }
  
  // Get unassigned serial numbers
  Future<List<SerialNumber>> getUnassignedSerials() async {
    final serials = await _getSerialNumbers();
    return serials.where((serial) => serial.assignedToUserId == null).toList();
  }
  
  // Get a user's serial number
  Future<SerialNumber?> getUserSerial(String email) async {
    final profiles = await _getUserProfiles();
    final serials = await _getSerialNumbers();
    
    // Find user by email
    final userList = profiles.where((profile) => profile.email == email).toList();
    if (userList.isEmpty) {
      return null; // Return null instead of throwing an exception
    }
    
    final user = userList.first;
    
    // Find serial assigned to user
    final userSerials = serials.where((serial) => serial.assignedToUserId == user.id).toList();
    if (userSerials.isEmpty) {
      return null; // Return null instead of throwing an exception
    }
    
    return userSerials.first;
  }
  
  // Get all users
  Future<List<UserProfile>> getAllUsers() async {
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