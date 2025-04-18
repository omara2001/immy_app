import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'backend_api_service.dart';

class AuthService {
  final String baseUrl = 'http://immy-database.czso7gvuv5td.eu-north-1.rds.amazonaws.comi'; // Replace with your API URL
  // Token storage key
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  
  // Register a new user
  Future<User> register(String name, String email, String password) async {
    try {
      // Try to create user in the database
      final userData = await BackendApiService.createUser(name, email, password);
      
      // Create a user object with a token
      final user = User(
        id: userData['id'],
        name: userData['name'],
        email: userData['email'],
        token: _generateToken(userData['id'].toString()),
        isAdmin: false,
      );
      
      // Save user data locally
      await _saveUserData(user);
      return user;
    } catch (e) {
      // If API call fails, try local authentication for admin
      if (email == 'administrator') {
        return _checkLocalAdminLogin(email, password);
      }
      throw Exception('Registration failed: $e');
    }
  }
  
  // Login user
  Future<User> login(String email, String password) async {
    try {
      // Special case for administrator login
      if (email == 'administrator' && password == 'admin') {
        return _checkLocalAdminLogin(email, password);
      }
      
      // Try to get user from database
      final userData = await BackendApiService.getUserByEmail(email);
      
      if (userData == null) {
        throw Exception('User not found');
      }
      
      // In a real app, you would verify the password hash here
      if (userData['password'] != password) {
        throw Exception('Invalid password');
      }
      
      // Create a user object with a token
      final user = User(
        id: userData['id'],
        name: userData['name'],
        email: userData['email'],
        token: _generateToken(userData['id'].toString()),
        isAdmin: false, // Set based on database value if available
      );
      
      // Save user data locally
      await _saveUserData(user);
      return user;
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
    
    // Get user ID from token
    final userId = _getUserIdFromToken(token);
    if (userId == null) {
      throw Exception('Invalid token');
    }
    
    // In a real app, you would fetch the user profile from the database
    // For now, we'll just return the current user data
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('User not found');
    }
    
    return {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'isAdmin': user.isAdmin,
    };
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
  
  // Generate a simple token (in a real app, use a proper JWT)
  String _generateToken(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return base64Encode(utf8.encode('$userId:$timestamp'));
  }
  
  // Extract user ID from token
  int? _getUserIdFromToken(String token) {
    try {
      final decoded = utf8.decode(base64Decode(token));
      final parts = decoded.split(':');
      if (parts.length == 2) {
        return int.parse(parts[0]);
      }
    } catch (e) {
      print("Error decoding token: $e");
    }
    return null;
  }
}


