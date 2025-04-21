import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show debugPrint;

class BackendApiService {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal();

  // MySQL connection settings
  static final _settings = ConnectionSettings(
    host: 'immy-database.czso7gvuv5td.eu-north-1.rds.amazonaws.com',
    port: 3306,
    user: 'admin',
    password: 'mypassword',
    db: 'mydb'
  );

  // API endpoint for web platform
  static const String apiBaseUrl = 'https://api.immyapp.com';

  // Get a MySQL connection
  static Future<MySqlConnection?> _getConnection() async {
    if (kIsWeb) {
      return null;
    }
    
    try {
      return await MySqlConnection.connect(_settings);
    } catch (e) {
      debugPrint('Database connection error: $e');
      return null;
    }
  }

  // Convert Results to List<Map<String, dynamic>>
  static List<Map<String, dynamic>> _convertResultsToList(Results results) {
    final List<Map<String, dynamic>> list = [];
    for (var row in results) {
      final Map<String, dynamic> map = {};
      for (var field in row.fields.keys) {
        map[field] = row[field];
      }
      list.add(map);
    }
    return list;
  }

  // Execute a query with platform-specific handling
  static Future<List<Map<String, dynamic>>> executeQuery(String query, [List<Object>? params]) async {
    if (kIsWeb) {
      // For web platform, make HTTP request to API
      final response = await http.post(
        Uri.parse('$apiBaseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'params': params,
        }),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((item) => 
            Map<String, dynamic>.from(item)
          ));
        }
        return [];
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } else {
      // For mobile platform, use direct database connection
      final conn = await _getConnection();
      if (conn == null) {
        throw Exception('Database connection not available');
      }

      try {
        final Results results = await conn.query(query, params);
        return _convertResultsToList(results);
      } finally {
        await conn.close();
      }
    }
  }

  // Database Initialization
  static Future<void> initializeDatabase() async {
    try {
      // Check if Users table exists
      final userTableExists = await executeQuery('''
        SELECT TABLE_NAME 
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Users'
      ''');
      
      if (userTableExists.isEmpty) {
        // Create Users table if it doesn't exist
        await executeQuery('''
          CREATE TABLE IF NOT EXISTS Users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255) NOT NULL UNIQUE,
            password VARCHAR(255),
            is_admin BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      } else {
        // Check if is_admin column exists
        final isAdminExists = await executeQuery('''
          SELECT COLUMN_NAME 
          FROM INFORMATION_SCHEMA.COLUMNS 
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Users' AND COLUMN_NAME = 'is_admin'
        ''');
        
        if (isAdminExists.isEmpty) {
          // Add is_admin column if it doesn't exist
          await executeQuery('ALTER TABLE Users ADD COLUMN is_admin BOOLEAN DEFAULT FALSE');
          debugPrint('Added is_admin column to Users table');
        }
      }

      // Create SerialNumbers table
      await executeQuery('''
        CREATE TABLE IF NOT EXISTS SerialNumbers (
          id INT AUTO_INCREMENT PRIMARY KEY,
          serial VARCHAR(255) NOT NULL UNIQUE,
          user_id INT,
          status VARCHAR(50) DEFAULT 'active',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE SET NULL
        )
      ''');

      // Create AudioRecords table
      await executeQuery('''
        CREATE TABLE IF NOT EXISTS AudioRecords (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id INT NOT NULL,
          audio_url TEXT NOT NULL,
          duration INT,
          recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          transcription_status VARCHAR(50) DEFAULT 'pending',
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE
        )
      ''');

      // Create Transcriptions table
      await executeQuery('''
        CREATE TABLE IF NOT EXISTS Transcriptions (
          id INT AUTO_INCREMENT PRIMARY KEY,
          audio_record_id INT NOT NULL,
          text TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (audio_record_id) REFERENCES AudioRecords(id) ON DELETE CASCADE
        )
      ''');

      debugPrint('Database initialized successfully');
    } catch (e) {
      debugPrint('Error initializing database: $e');
      throw Exception('Failed to initialize database: $e');
    }
  }

  // User Management Methods
  static Future<Map<String, dynamic>> createUser(String name, String email, String password) async {
    final results = await executeQuery(
      'INSERT INTO Users (name, email, password) VALUES (?, ?, ?)',
      [name, email, password]
    );

    return {
      'id': results.isEmpty ? null : results.first['LAST_INSERT_ID()'],
      'name': name,
      'email': email,
    };
  }

  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final results = await executeQuery(
      'SELECT * FROM Users WHERE email = ?',
      [email]
    );

    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }

  // Audio Record Management Methods
  static Future<Object> createAudioRecord(int userId, String audioUrl, int duration) async {
    final results = await executeQuery(
      'INSERT INTO AudioRecords (user_id, audio_url, duration) VALUES (?, ?, ?)',
      [userId, audioUrl, duration]
    );

    if (kIsWeb) {
      return results;
    } else {
      return {
        'id': results.isEmpty ? null : results.first['LAST_INSERT_ID()'],
        'user_id': userId,
        'audio_url': audioUrl,
        'duration': duration,
        'recorded_at': DateTime.now().toIso8601String(),
        'transcription_status': 'pending',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getUserAudioRecords(int userId) async {
    final results = await executeQuery('''
      SELECT 
        ar.*,
        t.text as transcription_text,
        t.created_at as transcription_date
      FROM AudioRecords ar
      LEFT JOIN Transcriptions t ON t.audio_record_id = ar.id
      WHERE ar.user_id = ?
      ORDER BY ar.recorded_at DESC
    ''', [userId]);

    if (kIsWeb) {
      if (results is List) {
        return List<Map<String, dynamic>>.from(results);
      }
      return [];
    } else {
      return results.map((row) => {
        'id': row['id'],
        'user_id': row['user_id'],
        'audio_url': row['audio_url'],
        'duration': row['duration'],
        'recorded_at': row['recorded_at'],
        'transcription_status': row['transcription_status'],
        'transcription_text': row['transcription_text'],
        'transcription_date': row['transcription_date'],
      }).toList();
    }
  }

  static Future<void> updateTranscriptionStatus(int audioRecordId, String status) async {
    await executeQuery(
      'UPDATE AudioRecords SET transcription_status = ? WHERE id = ?',
      [status, audioRecordId]
    );
  }

  static Future<void> saveTranscription(int audioRecordId, String text) async {
    await executeQuery(
      'INSERT INTO Transcriptions (audio_record_id, text) VALUES (?, ?)',
      [audioRecordId, text]
    );
    await updateTranscriptionStatus(audioRecordId, 'completed');
  }

  // QR Code Management Methods
  static Future<bool> assignQRCode(int userId, String qrCode) async {
    try {
      final existingQR = await executeQuery(
        'SELECT id FROM SerialNumbers WHERE serial = ?',
        [qrCode]
      );

      if (existingQR.isNotEmpty) {
        return false;
      }

      await executeQuery(
        'INSERT INTO SerialNumbers (serial, user_id, status) VALUES (?, ?, ?)',
        [qrCode, userId, 'active']
      );
      return true;
    } catch (e) {
      debugPrint('Error assigning QR code: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getQRCodesForUser(int userId) async {
    return await executeQuery(
      'SELECT * FROM SerialNumbers WHERE user_id = ?',
      [userId]
    );
  }

  // User Authentication Methods
  static Future<Map<String, dynamic>?> authenticateUser(String email, String password) async {
    final results = await executeQuery(
      'SELECT * FROM Users WHERE email = ? AND password = ?',
      [email, password]
    );

    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }

  // Admin Methods
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await executeQuery('SELECT * FROM Users ORDER BY created_at DESC');
  }

  static Future<void> setUserAdmin(int userId, bool isAdmin) async {
    await executeQuery(
      'UPDATE Users SET is_admin = ? WHERE id = ?',
      [isAdmin ? 1 : 0, userId]
    );
  }

  static Future<void> updateUserProfile(int userId, String name, String email) async {
    await executeQuery(
      'UPDATE Users SET name = ?, email = ? WHERE id = ?',
      [name, email, userId]
    );
  }

  static Future<void> changeUserPassword(int userId, String newPassword) async {
    await executeQuery(
      'UPDATE Users SET password = ? WHERE id = ?',
      [newPassword, userId]
    );
  }
}