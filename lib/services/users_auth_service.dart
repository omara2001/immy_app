import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  // Base URL for API - change this to your XAMPP server address
  final String baseUrl = 'http://localhost/immy_app/api'; // For Android emulator
  // Use 'http://localhost/immy_app/api' for iOS simulator or web
  // Use 'http://10.0.2.2/immy_app/api'; // Android emulator accessing localhost
  
  // Token storage key
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  
  // Register a new user
  Future<User> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    
    final data = jsonDecode(response.body);
    
    if (data['status'] == true) {
      final user = User.fromJson(data['data']);
      await _saveUserData(user);
      return user;
    } else {
      throw Exception(data['message']);
    }
  }
  
  // Login user
  Future<User> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    final data = jsonDecode(response.body);
    
    if (data['status'] == true) {
      final user = User.fromJson(data['data']);
      await _saveUserData(user);
      return user;
    } else {
      throw Exception(data['message']);
    }
  }
  
  // Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await getToken();
    
    if (token == null) {
      throw Exception('Not authenticated');
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl/profile.php'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    
    final data = jsonDecode(response.body);
    
    if (data['status'] == true) {
      return data['data'];
    } else {
      throw Exception(data['message']);
    }
  }
  
  // Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
  
  // Get current user
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    
    return null;
  }
  
  // Get auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  // Save user data to shared preferences
  Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, user.token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }
}

