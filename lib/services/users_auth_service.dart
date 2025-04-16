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
    try {
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
    } catch (e) {
      // If API call fails, try local authentication for admin
      if (email == 'administrator') {
        return _checkLocalAdminLogin(email, password);
      }
      throw Exception('Login failed: $e');
    }
  }
  
  // Login user
  Future<User> login(String email, String password) async {
    try {
      // Special case for administrator login
      if (email == 'administrator' && password == 'admin') {
        return _checkLocalAdminLogin(email, password);
      }
      
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
    } catch (e) {
      // If API call fails, try local authentication for admin
      if (email == 'administrator') {
        return _checkLocalAdminLogin(email, password);
      }
      throw Exception('Login failed: $e');
    }
  }
  
  // Check local admin login
  Future<User> _checkLocalAdminLogin(String email, String password) async {
    print("Checking local admin login: $email / $password");
    
    if (email == 'administrator' && password == 'admin') {
      // Create a local admin user
      final adminUser = User(
        id: 0,
        name: 'Administrator',
        email: 'administrator',
        token: 'local_admin_token',
        isAdmin: true,
      );
      
      print("Creating admin user with isAdmin: ${adminUser.isAdmin}");
      
      await _saveUserData(adminUser);
      return adminUser;
    } else {
      throw Exception('Invalid admin credentials');
    }
  }
  
  // Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await getToken();
    
    if (token == null) {
      throw Exception('Not authenticated');
    }
    
    // If it's a local admin token, return admin profile
    if (token == 'local_admin_token') {
      return {
        'id': 0,
        'name': 'Administrator',
        'email': 'administrator',
        'isAdmin': true,
      };
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
  
  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    final user = await getCurrentUser();
    final isAdmin = user?.isAdmin ?? false;
    print("Current user admin status: $isAdmin");
    return isAdmin;
  }
  
  // Get current user
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    
    if (userData != null) {
      try {
        final user = User.fromJson(jsonDecode(userData));
        print("Retrieved current user: ${user.name}, isAdmin: ${user.isAdmin}");
        return user;
      } catch (e) {
        print("Error parsing user data: $e");
        return null;
      }
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
    
    print("Saving user data: ${user.name}, isAdmin: ${user.isAdmin}");
    
    await prefs.setString(_tokenKey, user.token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    
    // Verify the data was saved correctly
    final savedData = prefs.getString(_userKey);
    if (savedData != null) {
      final savedUser = User.fromJson(jsonDecode(savedData));
      print("Verified saved user: ${savedUser.name}, isAdmin: ${savedUser.isAdmin}");
    }
  }
  
  // Initialize admin user if it doesn't exist
  Future<void> initializeAdminUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      
      // Check if we already have an admin user
      if (userData != null) {
        final user = User.fromJson(jsonDecode(userData));
        if (user.email == 'administrator' && user.isAdmin) {
          print("Admin user already exists");
          return;
        }
      }
      
      // Create admin user
      print("Creating initial admin user");
      final adminUser = User(
        id: 0,
        name: 'Administrator',
        email: 'administrator',
        token: 'local_admin_token',
        isAdmin: true,
      );
      
      await _saveUserData(adminUser);
      print("Initial admin user created");
    } catch (e) {
      print("Error initializing admin user: $e");
    }
  }
}
