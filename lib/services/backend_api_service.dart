import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BackendApiService {
  // API endpoint for web platform
  static const String apiBaseUrl = 'https://api.immyapp.com'; // Replace with your actual API endpoint
  
  // MySQL connection settings for native platforms
  static final _settings = ConnectionSettings(
    host: 'immy-database.czso7gvuv5td.eu-north-1.rds.amazonaws.com',
    port: 3306,
    user: 'admin',
    password: 'mypassword',
    db: 'mydb'
  );
  
  // Get a MySQL connection - with web platform check
  static Future<MySqlConnection?> _getConnection() async {
    if (kIsWeb) {
      // Web platform doesn't support direct socket connections
      return null;
    }
    
    try {
      return await MySqlConnection.connect(_settings);
    } catch (e) {
      print('Database connection error: $e');
      throw Exception('Failed to connect to database: $e');
    }
  }
  
  // Execute a query with platform-specific handling
  static Future<dynamic> _executeQuery(String query, [List<Object>? params]) async {
    if (kIsWeb) {
      // For web, we'll use a REST API endpoint instead
      // This is a placeholder - in a real implementation, you would make
      // HTTP requests to your backend API that can execute these queries
      
      // For now, we'll simulate some basic responses for common queries
      if (query.contains('SELECT 1')) {
        // Connection test
        return true;
      } else if (query.contains('CREATE TABLE')) {
        // Table creation
        return true;
      } else if (query.contains('SELECT * FROM Users')) {
        // Get all users
        return [
          {'id': 1, 'name': 'Administrator', 'email': 'administrator', 'created_at': DateTime.now().toIso8601String()},
          {'id': 2, 'name': 'Test User', 'email': 'user@example.com', 'created_at': DateTime.now().toIso8601String()}
        ];
      } else if (query.contains('SELECT * FROM SerialNumbers')) {
        // Get all serials
        return [
          {'id': 1, 'serial': 'IMMY-2025-123456', 'user_id': 1, 'created_at': DateTime.now().toIso8601String(), 'status': 'active'},
          {'id': 2, 'serial': 'IMMY-2025-234567', 'user_id': null, 'created_at': DateTime.now().toIso8601String(), 'status': 'active'}
        ];
      } else if (query.contains('INSERT INTO')) {
        // Insert operation
        return {'insertId': DateTime.now().millisecondsSinceEpoch % 1000};
      } else if (query.contains('UPDATE')) {
        // Update operation
        return true;
      }
      
      // Default fallback
      return [];
    } else {
      // Mobile platform - use direct database connection
      final conn = await _getConnection();
      if (conn == null) {
        throw Exception('Database connection not available');
      }
      
      try {
        return await conn.query(query, params);
      } finally {
        await conn.close();
      }
    }
  }
  
  // Initialize database tables if they don't exist
  static Future<void> initializeDatabase() async {
    try {
      // Create Users table if it doesn't exist
      await _executeQuery('''
        CREATE TABLE IF NOT EXISTS Users (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          email VARCHAR(255) NOT NULL UNIQUE,
          password VARCHAR(255),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create SerialNumbers table if it doesn't exist
      await _executeQuery('''
        CREATE TABLE IF NOT EXISTS SerialNumbers (
          id INT AUTO_INCREMENT PRIMARY KEY,
          serial VARCHAR(255) NOT NULL UNIQUE,
          user_id INT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          status VARCHAR(50) DEFAULT 'active',
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE SET NULL
        )
      ''');
      
      // Create other tables as needed
      await _executeQuery('''
        CREATE TABLE IF NOT EXISTS Subscriptions (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id INT NOT NULL,
          serial_id INT NOT NULL,
          start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          end_date TIMESTAMP NOT NULL,
          status VARCHAR(50) DEFAULT 'active',
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE,
          FOREIGN KEY (serial_id) REFERENCES SerialNumbers(id) ON DELETE CASCADE
        )
      ''');
      
      await _executeQuery('''
        CREATE TABLE IF NOT EXISTS Payments (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id INT NOT NULL,
          serial_id INT NOT NULL,
          amount DECIMAL(10, 2) NOT NULL,
          currency VARCHAR(10) NOT NULL,
          payment_status VARCHAR(50) DEFAULT 'pending',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE,
          FOREIGN KEY (serial_id) REFERENCES SerialNumbers(id) ON DELETE CASCADE
        )
      ''');
      
      await _executeQuery('''
        CREATE TABLE IF NOT EXISTS AudioRecords (
          id INT AUTO_INCREMENT PRIMARY KEY,
          serial_id INT NOT NULL,
          user_id INT NOT NULL,
          audio_url TEXT NOT NULL,
          recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (serial_id) REFERENCES SerialNumbers(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE
        )
      ''');
      
      await _executeQuery('''
        CREATE TABLE IF NOT EXISTS Transcriptions (
          id INT AUTO_INCREMENT PRIMARY KEY,
          audio_id INT NOT NULL,
          serial_id INT NOT NULL,
          user_id INT NOT NULL,
          transcribed_text TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (audio_id) REFERENCES AudioRecords(id) ON DELETE CASCADE,
          FOREIGN KEY (serial_id) REFERENCES SerialNumbers(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE
        )
      ''');
      
      await _executeQuery('''
        CREATE TABLE IF NOT EXISTS Insights (
          id INT AUTO_INCREMENT PRIMARY KEY,
          transcription_id INT NOT NULL,
          serial_id INT NOT NULL,
          user_id INT NOT NULL,
          insight TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (transcription_id) REFERENCES Transcriptions(id) ON DELETE CASCADE,
          FOREIGN KEY (serial_id) REFERENCES SerialNumbers(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE
        )
      ''');
      
      print('Database initialized successfully');
    } catch (e) {
      print('Error initializing database: $e');
      throw Exception('Failed to initialize database: $e');
    }
  }
  
  // ==================== USER OPERATIONS ====================
  
  // Create a new user
  static Future<Map<String, dynamic>> createUser(String name, String email, String password) async {
    final hashedPassword = password; // In a real app, hash the password
    
    final results = await _executeQuery(
      'INSERT INTO Users (name, email, password) VALUES (?, ?, ?)',
      [name, email, hashedPassword]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return {
        'id': results['insertId'],
        'name': name,
        'email': email,
      };
    } else {
      // For mobile, we have the actual MySQL results
      return {
        'id': results.insertId,
        'name': name,
        'email': email,
      };
    }
  }
  
  // Get user by email
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final results = await _executeQuery(
      'SELECT * FROM Users WHERE email = ?',
      [email]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List && results.isNotEmpty) {
        for (var user in results) {
          if (user['email'] == email) {
            return user;
          }
        }
      }
      return null;
    } else {
      // For mobile, we have the actual MySQL results
      if (results.isEmpty) {
        return null;
      }
      
      final row = results.first;
      return {
        'id': row['id'],
        'name': row['name'],
        'email': row['email'],
        'password': row['password'],
        'created_at': row['created_at'],
      };
    }
  }
  
  // Get all users
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final results = await _executeQuery('SELECT * FROM Users');
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List) {
        return List<Map<String, dynamic>>.from(results);
      }
      return [];
    } else {
      // For mobile, we have the actual MySQL results
      return results.map((row) => {
        'id': row['id'],
        'name': row['name'],
        'email': row['email'],
        'created_at': row['created_at'],
      }).toList();
    }
  }
  
  // ==================== SERIAL NUMBER OPERATIONS ====================
  
  // Create a new serial number
  static Future<Map<String, dynamic>> createSerialNumber(String serial) async {
    final results = await _executeQuery(
      'INSERT INTO SerialNumbers (serial) VALUES (?)',
      [serial]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return {
        'id': results['insertId'],
        'serial': serial,
        'created_at': DateTime.now().toIso8601String(),
      };
    } else {
      // For mobile, we have the actual MySQL results
      return {
        'id': results.insertId,
        'serial': serial,
        'created_at': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Get all serial numbers
  static Future<List<Map<String, dynamic>>> getAllSerialNumbers() async {
    final results = await _executeQuery('SELECT * FROM SerialNumbers');
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List) {
        return List<Map<String, dynamic>>.from(results);
      }
      return [];
    } else {
      // For mobile, we have the actual MySQL results
      return results.map((row) => {
        'id': row['id'],
        'serial': row['serial'],
        'user_id': row['user_id'],
        'created_at': row['created_at'],
        'status': row['status'],
      }).toList();
    }
  }
  
  // Assign serial to user
  static Future<void> assignSerialToUser(int serialId, int userId) async {
    await _executeQuery(
      'UPDATE SerialNumbers SET user_id = ? WHERE id = ?',
      [userId, serialId]
    );
  }
  
  // ==================== SUBSCRIPTION OPERATIONS ====================
  
  // Create a subscription
  static Future<Map<String, dynamic>> createSubscription(int userId, int serialId, DateTime endDate) async {
    final results = await _executeQuery(
      'INSERT INTO Subscriptions (user_id, serial_id, end_date) VALUES (?, ?, ?)',
      [userId, serialId, endDate.toIso8601String()]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return {
        'id': results['insertId'],
        'user_id': userId,
        'serial_id': serialId,
        'start_date': DateTime.now().toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'active',
      };
    } else {
      // For mobile, we have the actual MySQL results
      return {
        'id': results.insertId,
        'user_id': userId,
        'serial_id': serialId,
        'start_date': DateTime.now().toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'active',
      };
    }
  }
  
  // Get user subscriptions
  static Future<List<Map<String, dynamic>>> getUserSubscriptions(int userId) async {
    final results = await _executeQuery(
      'SELECT * FROM Subscriptions WHERE user_id = ?',
      [userId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List) {
        return List<Map<String, dynamic>>.from(results.where((sub) => sub['user_id'] == userId));
      }
      return [];
    } else {
      // For mobile, we have the actual MySQL results
      return results.map((row) => {
        'id': row['id'],
        'user_id': row['user_id'],
        'serial_id': row['serial_id'],
        'start_date': row['start_date'],
        'end_date': row['end_date'],
        'status': row['status'],
      }).toList();
    }
  }
  
  // ==================== PAYMENT OPERATIONS ====================
  
  // Create a payment
  static Future<Map<String, dynamic>> createPayment(int userId, int serialId, double amount, String currency) async {
    final results = await _executeQuery(
      'INSERT INTO Payments (user_id, serial_id, amount, currency) VALUES (?, ?, ?, ?)',
      [userId, serialId, amount, currency]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return {
        'id': results['insertId'],
        'user_id': userId,
        'serial_id': serialId,
        'amount': amount,
        'currency': currency,
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };
    } else {
      // For mobile, we have the actual MySQL results
      return {
        'id': results.insertId,
        'user_id': userId,
        'serial_id': serialId,
        'amount': amount,
        'currency': currency,
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Get user payments
  static Future<List<Map<String, dynamic>>> getUserPayments(int userId) async {
    final results = await _executeQuery(
      'SELECT * FROM Payments WHERE user_id = ?',
      [userId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List) {
        return List<Map<String, dynamic>>.from(results.where((payment) => payment['user_id'] == userId));
      }
      return [];
    } else {
      // For mobile, we have the actual MySQL results
      return results.map((row) => {
        'id': row['id'],
        'user_id': row['user_id'],
        'serial_id': row['serial_id'],
        'amount': row['amount'],
        'currency': row['currency'],
        'payment_status': row['payment_status'],
        'created_at': row['created_at'],
      }).toList();
    }
  }
  
  // ==================== AUDIO RECORDS OPERATIONS ====================
  
  // Create an audio record
  static Future<Map<String, dynamic>> createAudioRecord(int serialId, int userId, String audioUrl) async {
    final results = await _executeQuery(
      'INSERT INTO AudioRecords (serial_id, user_id, audio_url) VALUES (?, ?, ?)',
      [serialId, userId, audioUrl]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return {
        'id': results['insertId'],
        'serial_id': serialId,
        'user_id': userId,
        'audio_url': audioUrl,
        'recorded_at': DateTime.now().toIso8601String(),
      };
    } else {
      // For mobile, we have the actual MySQL results
      return {
        'id': results.insertId,
        'serial_id': serialId,
        'user_id': userId,
        'audio_url': audioUrl,
        'recorded_at': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Get user audio records
  static Future<List<Map<String, dynamic>>> getUserAudioRecords(int userId) async {
    final results = await _executeQuery(
      'SELECT * FROM AudioRecords WHERE user_id = ?',
      [userId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List) {
        return List<Map<String, dynamic>>.from(results.where((record) => record['user_id'] == userId));
      }
      return [];
    } else {
      // For mobile, we have the actual MySQL results
      return results.map((row) => {
        'id': row['id'],
        'serial_id': row['serial_id'],
        'user_id': row['user_id'],
        'audio_url': row['audio_url'],
        'recorded_at': row['recorded_at'],
      }).toList();
    }
  }
  
  // ==================== TRANSCRIPTION OPERATIONS ====================
  
  // Create a transcription
  static Future<Map<String, dynamic>> createTranscription(int audioId, int serialId, int userId, String text) async {
    final results = await _executeQuery(
      'INSERT INTO Transcriptions (audio_id, serial_id, user_id, transcribed_text) VALUES (?, ?, ?, ?)',
      [audioId, serialId, userId, text]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return {
        'id': results['insertId'],
        'audio_id': audioId,
        'serial_id': serialId,
        'user_id': userId,
        'transcribed_text': text,
        'created_at': DateTime.now().toIso8601String(),
      };
    } else {
      // For mobile, we have the actual MySQL results
      return {
        'id': results.insertId,
        'audio_id': audioId,
        'serial_id': serialId,
        'user_id': userId,
        'transcribed_text': text,
        'created_at': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Get transcriptions by audio ID
  static Future<List<Map<String, dynamic>>> getTranscriptionsByAudioId(int audioId) async {
    final results = await _executeQuery(
      'SELECT * FROM Transcriptions WHERE audio_id = ?',
      [audioId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List) {
        return List<Map<String, dynamic>>.from(results.where((trans) => trans['audio_id'] == audioId));
      }
      return [];
    } else {
      // For mobile, we have the actual MySQL results
      return results.map((row) => {
        'id': row['id'],
        'audio_id': row['audio_id'],
        'serial_id': row['serial_id'],
        'user_id': row['user_id'],
        'transcribed_text': row['transcribed_text'],
        'created_at': row['created_at'],
      }).toList();
    }
  }
  
  // ==================== INSIGHTS OPERATIONS ====================
  
  // Create an insight
  static Future<Map<String, dynamic>> createInsight(int transcriptionId, int serialId, int userId, String insight) async {
    final results = await _executeQuery(
      'INSERT INTO Insights (transcription_id, serial_id, user_id, insight) VALUES (?, ?, ?, ?)',
      [transcriptionId, serialId, userId, insight]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return {
        'id': results['insertId'],
        'transcription_id': transcriptionId,
        'serial_id': serialId,
        'user_id': userId,
        'insight': insight,
        'created_at': DateTime.now().toIso8601String(),
      };
    } else {
      // For mobile, we have the actual MySQL results
      return {
        'id': results.insertId,
        'transcription_id': transcriptionId,
        'serial_id': serialId,
        'user_id': userId,
        'insight': insight,
        'created_at': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Get insights by transcription ID
  static Future<List<Map<String, dynamic>>> getInsightsByTranscriptionId(int transcriptionId) async {
    final results = await _executeQuery(
      'SELECT * FROM Insights WHERE transcription_id = ?',
      [transcriptionId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      if (results is List) {
        return List<Map<String, dynamic>>.from(results.where((insight) => insight['transcription_id'] == transcriptionId));
      }
      return [];
    } else {
      // For mobile, we have the actual MySQL results
      return results.map((row) => {
        'id': row['id'],
        'transcription_id': row['transcription_id'],
        'serial_id': row['serial_id'],
        'user_id': row['user_id'],
        'insight': row['insight'],
        'created_at': row['created_at'],
      }).toList();
    }
  }
  
  // ==================== UTILITY METHODS ====================
  
  // Test database connection
  static Future<bool> testConnection() async {
    try {
      if (kIsWeb) {
        // For web, we'll just return true for now
        // In a real app, you'd make an API call to test the connection
        return true;
      } else {
        // For mobile, test the actual connection
        final conn = await _getConnection();
        if (conn == null) {
          return false;
        }
        await conn.query('SELECT 1');
        await conn.close();
        return true;
      }
    } catch (e) {
      print('Database connection test failed: $e');
      return false;
    }
  }
  
  // In a real implementation, you would add methods to make actual API calls for web
  // For example:
  static Future<Map<String, dynamic>> _makeApiCall(String endpoint, Map<String, dynamic> data) async {
    if (!kIsWeb) {
      throw Exception('API calls should only be made from web platform');
    }
    
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API call failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('API call error: $e');
      throw Exception('Failed to make API call: $e');
    }
  }
}