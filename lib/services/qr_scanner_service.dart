import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/serial_number.dart';
import 'serial_service.dart';
import 'dart:convert' show json; // Import for JSON operations

class QrScannerService {
  final SerialService _serialService;
  
  QrScannerService(this._serialService);
  
  // Process a scanned QR code
  Future<Map<String, dynamic>> processScannedCode(String code) async {
    // Validate the format of the QR code
    if (!_isValidImmyCode(code)) {
      return {
        'success': false,
        'message': 'Invalid QR code format. Expected an Immy Bear serial number.',
        'code': code,
      };
    }
    
    try {
      // Get all serial numbers (this will check admin access)
      List<SerialNumber> allSerials = [];
      try {
        // Try to get all serials (admin only)
        allSerials = await _serialService.getSerialList();
      } catch (e) {
        // If not admin, we'll need to handle this differently
        // For now, we'll use a workaround to check if the serial exists
        final prefs = await SharedPreferences.getInstance();
        final serialsJson = prefs.getString('serial_numbers');
        if (serialsJson != null) {
          final List<dynamic> decoded = serialsJson != null ? 
              await compute(jsonDecode, serialsJson) : [];
          allSerials = decoded.map((json) => SerialNumber.fromJson(json)).toList();
        }
      }
      
      // Find the matching serial
      final matchingSerials = allSerials.where((s) => s.serial == code).toList();
      
      if (matchingSerials.isEmpty) {
        return {
          'success': false,
          'message': 'This serial number is not registered in our system.',
          'code': code,
        };
      }
      
      final serial = matchingSerials.first;
      return {
        'success': true,
        'message': 'Valid Immy Bear serial number detected.',
        'serial': serial,
        'isAssigned': serial.assignedToUserId != null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing QR code: $e',
        'code': code,
      };
    }
  }
  
  // Check if the code matches the Immy Bear format
  bool _isValidImmyCode(String code) {
    // Check if the code starts with IMMY-
    return code.startsWith('IMMY-');
  }
  
  // Get recent scans from local storage
  Future<List<String>> getRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recent_scans') ?? [];
  }
  
  // Save a scan to recent scans
  Future<void> saveRecentScan(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final recentScans = prefs.getStringList('recent_scans') ?? [];
    
    // Remove the code if it already exists
    recentScans.remove(code);
    
    // Add to the beginning of the list
    recentScans.insert(0, code);
    
    // Keep only the last 10 scans
    final limitedScans = recentScans.take(10).toList();
    
    await prefs.setStringList('recent_scans', limitedScans);
  }
  
  // Clear recent scans
  Future<void> clearRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_scans');
  }
}

// Helper function to run JSON decode in a separate isolate
Future<dynamic> compute(Function(dynamic) callback, dynamic message) async {
  return callback(message);
}

// JSON decode function
dynamic jsonDecode(dynamic message) {
  return json.decode(message);
}


