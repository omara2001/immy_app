import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';

class BackendApiService {
  // MySQL connection settings
  static final _settings = ConnectionSettings(
    host: 'immy-database.czso7gvuv5td.eu-north-1.rds.amazonaws.com',
    port: 3306,
    user: 'admin',
    password: 'mypassword',
    db: 'mydb'
  );
  
  // Get a MySQL connection
  static Future<MySqlConnection> _getConnection() async {
    return await MySqlConnection.connect(_settings);
  }
  
  // Execute a query
  static Future<Results> _executeQuery(String query, [List<Object>? params]) async {
    final conn = await _getConnection();
    try {
      return await conn.query(query, params);
    } finally {
      await conn.close();
    }
  }
  
  // User operations
  static Future<Map<String, dynamic>> createUser(String name, String email, String password) async {
    final hashedPassword = password; // In a real app, hash the password
    
    final results = await _executeQuery(
      'INSERT INTO Users (name, email, password) VALUES (?, ?, ?)',
      [name, email, hashedPassword]
    );
    
    return {
      'id': results.insertId,
      'name': name,
      'email': email,
    };
  }
  
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final results = await _executeQuery(
      'SELECT * FROM Users WHERE email = ?',
      [email]
    );
    
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
  
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final results = await _executeQuery('SELECT * FROM Users');
    
    return results.map((row) => {
      'id': row['id'],
      'name': row['name'],
      'email': row['email'],
      'created_at': row['created_at'],
    }).toList();
  }
  
  // Serial number operations
  static Future<Map<String, dynamic>> createSerialNumber(String serial) async {
    final results = await _executeQuery(
      'INSERT INTO SerialNumbers (serial) VALUES (?)',
      [serial]
    );
    
    return {
      'id': results.insertId,
      'serial': serial,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  static Future<List<Map<String, dynamic>>> getAllSerialNumbers() async {
    final results = await _executeQuery('SELECT * FROM SerialNumbers');
    
    return results.map((row) => {
      'id': row['id'],
      'serial': row['serial'],
      'user_id': row['user_id'],
      'created_at': row['created_at'],
      'status': row['status'],
    }).toList();
  }
  
  static Future<void> assignSerialToUser(int serialId, int userId) async {
    await _executeQuery(
      'UPDATE SerialNumbers SET user_id = ? WHERE id = ?',
      [userId, serialId]
    );
  }
  
  // Subscription operations
  static Future<Map<String, dynamic>> createSubscription(int userId, int serialId, DateTime endDate) async {
    final results = await _executeQuery(
      'INSERT INTO Subscriptions (user_id, serial_id, end_date) VALUES (?, ?, ?)',
      [userId, serialId, endDate.toIso8601String()]
    );
    
    return {
      'id': results.insertId,
      'user_id': userId,
      'serial_id': serialId,
      'start_date': DateTime.now().toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'active',
    };
  }
  
  static Future<List<Map<String, dynamic>>> getUserSubscriptions(int userId) async {
    final results = await _executeQuery(
      'SELECT * FROM Subscriptions WHERE user_id = ?',
      [userId]
    );
    
    return results.map((row) => {
      'id': row['id'],
      'user_id': row['user_id'],
      'serial_id': row['serial_id'],
      'start_date': row['start_date'],
      'end_date': row['end_date'],
      'status': row['status'],
    }).toList();
  }
  
  // Payment operations
  static Future<Map<String, dynamic>> createPayment(int userId, int serialId, double amount, String currency) async {
    final results = await _executeQuery(
      'INSERT INTO Payments (user_id, serial_id, amount, currency) VALUES (?, ?, ?, ?)',
      [userId, serialId, amount, currency]
    );
    
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
  
  static Future<List<Map<String, dynamic>>> getUserPayments(int userId) async {
    final results = await _executeQuery(
      'SELECT * FROM Payments WHERE user_id = ?',
      [userId]
    );
    
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
  
  // Audio records operations
  static Future<Map<String, dynamic>> createAudioRecord(int serialId, int userId, String audioUrl) async {
    final results = await _executeQuery(
      'INSERT INTO AudioRecords (serial_id, user_id, audio_url) VALUES (?, ?, ?)',
      [serialId, userId, audioUrl]
    );
    
    return {
      'id': results.insertId,
      'serial_id': serialId,
      'user_id': userId,
      'audio_url': audioUrl,
      'recorded_at': DateTime.now().toIso8601String(),
    };
  }
  
  static Future<List<Map<String, dynamic>>> getUserAudioRecords(int userId) async {
    final results = await _executeQuery(
      'SELECT * FROM AudioRecords WHERE user_id = ?',
      [userId]
    );
    
    return results.map((row) => {
      'id': row['id'],
      'serial_id': row['serial_id'],
      'user_id': row['user_id'],
      'audio_url': row['audio_url'],
      'recorded_at': row['recorded_at'],
    }).toList();
  }
  
  // Transcription operations
  static Future<Map<String, dynamic>> createTranscription(int audioId, int serialId, int userId, String text) async {
    final results = await _executeQuery(
      'INSERT INTO Transcriptions (audio_id, serial_id, user_id, transcribed_text) VALUES (?, ?, ?, ?)',
      [audioId, serialId, userId, text]
    );
    
    return {
      'id': results.insertId,
      'audio_id': audioId,
      'serial_id': serialId,
      'user_id': userId,
      'transcribed_text': text,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  static Future<List<Map<String, dynamic>>> getTranscriptionsByAudioId(int audioId) async {
    final results = await _executeQuery(
      'SELECT * FROM Transcriptions WHERE audio_id = ?',
      [audioId]
    );
    
    return results.map((row) => {
      'id': row['id'],
      'audio_id': row['audio_id'],
      'serial_id': row['serial_id'],
      'user_id': row['user_id'],
      'transcribed_text': row['transcribed_text'],
      'created_at': row['created_at'],
    }).toList();
  }
  
  // Insights operations
  static Future<Map<String, dynamic>> createInsight(int transcriptionId, int serialId, int userId, String insight) async {
    final results = await _executeQuery(
      'INSERT INTO Insights (transcription_id, serial_id, user_id, insight) VALUES (?, ?, ?, ?)',
      [transcriptionId, serialId, userId, insight]
    );
    
    return {
      'id': results.insertId,
      'transcription_id': transcriptionId,
      'serial_id': serialId,
      'user_id': userId,
      'insight': insight,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  static Future<List<Map<String, dynamic>>> getInsightsByTranscriptionId(int transcriptionId) async {
    final results = await _executeQuery(
      'SELECT * FROM Insights WHERE transcription_id = ?',
      [transcriptionId]
    );
    
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
