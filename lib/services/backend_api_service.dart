import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BackendApiService {
  // API endpoint for web platform
  static const String apiBaseUrl = 'https://api.immyapp.com'; // Replace with your actual API endpoint
  
  static MySqlConnection? _connection;
  
  // MySQL connection settings
  static final _settings = ConnectionSettings(
    host: 'immy-database.czso7gvuv5td.eu-north-1.rds.amazonaws.com',
    port: 3306,
    user: 'admin',
    password: 'mypassword',
    db: 'mydb'
  );
  
  // Initialize the database connection
  static Future<void> initialize() async {
    if (!kIsWeb) {
      try {
        _connection = await MySqlConnection.connect(_settings);
        await initializeDatabase();
      } catch (e) {
        print('Error initializing database connection: $e');
        throw Exception('Failed to initialize database connection: $e');
      }
    }
  }
  
  // Get a MySQL connection
  static Future<MySqlConnection> _getConnection() async {
    if (kIsWeb) {
      throw Exception('Direct database connection not supported on web platform');
    }
    
    if (_connection == null) {
      await initialize();
    }
    
    return _connection!;
  }
  
  // Initialize database tables
  static Future<void> initializeDatabase() async {
    try {
      final conn = await _getConnection();
      
      // Create Users table
      await conn.query('''
        CREATE TABLE IF NOT EXISTS Users (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          email VARCHAR(255) NOT NULL UNIQUE,
          password VARCHAR(255),
          is_admin BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
      ''');

      // Check if SerialNumbers table exists and its structure
      final tables = await conn.query("SHOW TABLES LIKE 'SerialNumbers'");
      if (tables.isEmpty) {
        // Create SerialNumbers table with assigned_at column
        await conn.query('''
          CREATE TABLE IF NOT EXISTS SerialNumbers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            serial VARCHAR(255) NOT NULL UNIQUE,
            user_id INT,
            status VARCHAR(50) DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            assigned_at TIMESTAMP NULL,
            FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE SET NULL
          )
        ''');
      } else {
        // Check if assigned_at column exists
        final columns = await conn.query("SHOW COLUMNS FROM SerialNumbers LIKE 'assigned_at'");
        if (columns.isEmpty) {
          // Add the missing assigned_at column
          await conn.query("ALTER TABLE SerialNumbers ADD COLUMN assigned_at TIMESTAMP NULL");
          print('Added missing assigned_at column to SerialNumbers table');
        }
      }
      
      // Create other tables as needed
      await conn.query('''
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
      
      await conn.query('''
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
      
      await conn.query('''
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
      
      await conn.query('''
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
      
      await conn.query('''
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
  
  // Execute a query
  static Future<List<Map<String, dynamic>>> executeQuery(String query, [List<Object>? params]) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/query'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': query,
            'params': params,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return List<Map<String, dynamic>>.from(data['results']);
        } else {
          throw Exception('API request failed with status ${response.statusCode}');
        }
      } catch (e) {
        print('API error: $e');
        throw Exception('Failed to execute query: $e');
      }
    } else {
      final conn = await _getConnection();
      try {
        final Results results = await conn.query(query, params ?? []);
        return results.map((row) => Map<String, dynamic>.from(row.fields)).toList();
      } catch (e) {
        print('Database error: $e');
        throw Exception('Failed to execute query: $e');
      }
    }
  }

  // Execute an insert query
  static Future<int> executeInsert(String query, [List<Object>? params]) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/insert'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': query,
            'params': params,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['insertId'] as int;
        } else {
          throw Exception('API request failed with status ${response.statusCode}');
        }
      } catch (e) {
        print('API error: $e');
        throw Exception('Failed to execute insert: $e');
      }
    } else {
      final conn = await _getConnection();
      try {
        final Results result = await conn.query(query, params ?? []);
        return result.insertId ?? -1;
      } catch (e) {
        print('Database error: $e');
        throw Exception('Failed to execute insert: $e');
      }
    }
  }

  // Execute a batch insert
  static Future<void> executeBatchInsert(String query, List<List<Object>> batchParams) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/batch-insert'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': query,
            'batchParams': batchParams,
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('API request failed with status ${response.statusCode}');
        }
      } catch (e) {
        print('API error: $e');
        throw Exception('Failed to execute batch insert: $e');
      }
    } else {
      final conn = await _getConnection();
      try {
        await conn.queryMulti(query, batchParams);
      } catch (e) {
        print('Database error: $e');
        throw Exception('Failed to execute batch insert: $e');
      }
    }
  }
  
  // ==================== USER OPERATIONS ====================
  
  // Create a new user
  static Future<Map<String, dynamic>> createUser(String name, String email, String password) async {
    final hashedPassword = password; // In a real app, hash the password
    
    final insertId = await executeInsert(
      'INSERT INTO Users (name, email, password) VALUES (?, ?, ?)',
      [name, email, hashedPassword]
    );
    
    return {
      'id': insertId,
      'name': name,
      'email': email,
    };
  }
  
  // Get user by email
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
  
  // Get all users
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final results = await executeQuery('SELECT * FROM Users');
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return List<Map<String, dynamic>>.from(results);
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
    final insertId = await executeInsert(
      'INSERT INTO SerialNumbers (serial) VALUES (?)',
      [serial]
    );
    
    return {
      'id': insertId,
      'serial': serial,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Get all serial numbers
  static Future<List<Map<String, dynamic>>> getAllSerialNumbers() async {
    final results = await executeQuery('SELECT * FROM SerialNumbers');
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return List<Map<String, dynamic>>.from(results);
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
    await executeQuery(
      'UPDATE SerialNumbers SET user_id = ? WHERE id = ?',
      [userId, serialId]
    );
  }
  
  // ==================== SUBSCRIPTION OPERATIONS ====================
  
  // Create a subscription
  static Future<Map<String, dynamic>> createSubscription(int userId, int serialId, DateTime endDate) async {
    final insertId = await executeInsert(
      'INSERT INTO Subscriptions (user_id, serial_id, end_date) VALUES (?, ?, ?)',
      [userId, serialId, endDate.toIso8601String()]
    );
    
    return {
      'id': insertId,
      'user_id': userId,
      'serial_id': serialId,
      'start_date': DateTime.now().toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'active',
    };
  }
  
  // Get user subscriptions
  static Future<List<Map<String, dynamic>>> getUserSubscriptions(int userId) async {
    final results = await executeQuery(
      'SELECT * FROM Subscriptions WHERE user_id = ?',
      [userId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return List<Map<String, dynamic>>.from(results.where((sub) => sub['user_id'] == userId));
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
    final insertId = await executeInsert(
      'INSERT INTO Payments (user_id, serial_id, amount, currency) VALUES (?, ?, ?, ?)',
      [userId, serialId, amount, currency]
    );
    
    return {
      'id': insertId,
      'user_id': userId,
      'serial_id': serialId,
      'amount': amount,
      'currency': currency,
      'payment_status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Get user payments
  static Future<List<Map<String, dynamic>>> getUserPayments(int userId) async {
    final results = await executeQuery(
      'SELECT * FROM Payments WHERE user_id = ?',
      [userId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return List<Map<String, dynamic>>.from(results.where((payment) => payment['user_id'] == userId));
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
    final insertId = await executeInsert(
      'INSERT INTO AudioRecords (serial_id, user_id, audio_url) VALUES (?, ?, ?)',
      [serialId, userId, audioUrl]
    );
    
    return {
      'id': insertId,
      'serial_id': serialId,
      'user_id': userId,
      'audio_url': audioUrl,
      'recorded_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Get user audio records
  static Future<List<Map<String, dynamic>>> getUserAudioRecords(int userId) async {
    final results = await executeQuery(
      'SELECT * FROM AudioRecords WHERE user_id = ?',
      [userId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return List<Map<String, dynamic>>.from(results.where((record) => record['user_id'] == userId));
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
    final insertId = await executeInsert(
      'INSERT INTO Transcriptions (audio_id, serial_id, user_id, transcribed_text) VALUES (?, ?, ?, ?)',
      [audioId, serialId, userId, text]
    );
    
    return {
      'id': insertId,
      'audio_id': audioId,
      'serial_id': serialId,
      'user_id': userId,
      'transcribed_text': text,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Get transcriptions by audio ID
  static Future<List<Map<String, dynamic>>> getTranscriptionsByAudioId(int audioId) async {
    final results = await executeQuery(
      'SELECT * FROM Transcriptions WHERE audio_id = ?',
      [audioId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return List<Map<String, dynamic>>.from(results.where((trans) => trans['audio_id'] == audioId));
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
    final insertId = await executeInsert(
      'INSERT INTO Insights (transcription_id, serial_id, user_id, insight) VALUES (?, ?, ?, ?)',
      [transcriptionId, serialId, userId, insight]
    );
    
    return {
      'id': insertId,
      'transcription_id': transcriptionId,
      'serial_id': serialId,
      'user_id': userId,
      'insight': insight,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  // Get insights by transcription ID
  static Future<List<Map<String, dynamic>>> getInsightsByTranscriptionId(int transcriptionId) async {
    final results = await executeQuery(
      'SELECT * FROM Insights WHERE transcription_id = ?',
      [transcriptionId]
    );
    
    if (kIsWeb) {
      // For web, we're using our simulated response
      return List<Map<String, dynamic>>.from(results.where((insight) => insight['transcription_id'] == transcriptionId));
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
        final response = await http.get(Uri.parse('$apiBaseUrl/health'));
        return response.statusCode == 200;
      } else {
        final conn = await _getConnection();
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

  // Get all QR codes
  static Future<List<Map<String, dynamic>>> getAllQRCodes() async {
    try {
      // Check if assigned_at column exists
      if (!kIsWeb) {
        final conn = await _getConnection();
        final columns = await conn.query("SHOW COLUMNS FROM SerialNumbers LIKE 'assigned_at'");
        
        if (columns.isEmpty) {
          // If assigned_at doesn't exist, use a query without it
          return await executeQuery('''
            SELECT 
              s.id,
              s.serial,
              s.status,
              s.created_at,
              s.user_id,
              u.name as assigned_to_name,
              u.email as assigned_to_email
            FROM SerialNumbers s
            LEFT JOIN Users u ON s.user_id = u.id
            ORDER BY s.created_at DESC
          ''');
        }
      }
      
      // If assigned_at exists or we're on web, use the original query
      return await executeQuery('''
        SELECT 
          s.id,
          s.serial,
          s.status,
          s.created_at,
          s.assigned_at,
          s.user_id,
          u.name as assigned_to_name,
          u.email as assigned_to_email
        FROM SerialNumbers s
        LEFT JOIN Users u ON s.user_id = u.id
        ORDER BY s.created_at DESC
      ''');
    } catch (e) {
      print('Error fetching QR codes: $e');
      throw Exception('Failed to fetch QR codes: $e');
    }
  }

  // Get available QR codes
  static Future<List<Map<String, dynamic>>> getAvailableQRCodes() async {
    return await executeQuery('''
      SELECT 
        id,
        serial,
        status,
        created_at
      FROM SerialNumbers
      WHERE user_id IS NULL AND status = 'active'
      ORDER BY created_at DESC
    ''');
  }

  // Assign QR code to user
  static Future<void> assignQRCodeToUser(int serialId, int userId) async {
    try {
      // Check if assigned_at column exists
      if (!kIsWeb) {
        final conn = await _getConnection();
        final columns = await conn.query("SHOW COLUMNS FROM SerialNumbers LIKE 'assigned_at'");
        
        if (columns.isEmpty) {
          // If assigned_at doesn't exist, use a query without it
          await executeQuery('''
            UPDATE SerialNumbers 
            SET user_id = ?, 
                status = 'assigned'
            WHERE id = ? AND user_id IS NULL
          ''', [userId, serialId]);
          return;
        }
      }
      
      // If assigned_at exists or we're on web, use the original query
      await executeQuery('''
        UPDATE SerialNumbers 
        SET user_id = ?, 
            assigned_at = CURRENT_TIMESTAMP,
            status = 'assigned'
        WHERE id = ? AND user_id IS NULL
      ''', [userId, serialId]);
    } catch (e) {
      print('Error assigning QR code: $e');
      throw Exception('Failed to assign QR code: $e');
    }
  }

  // Create new QR codes
  static Future<List<Map<String, dynamic>>> createQRCodes(List<String> serials) async {
    final batch = serials.map((serial) => [serial, 'active']).toList();
    
    await executeBatchInsert(
      'INSERT INTO SerialNumbers (serial, status) VALUES (?, ?)',
      batch
    );
    
    return await executeQuery(
      'SELECT * FROM SerialNumbers WHERE serial IN (${List.filled(serials.length, '?').join(',')})',
      serials
    );
  }

  // Close the database connection
  static Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
    }
  }
}