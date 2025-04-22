import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'backend_api_service.dart';

class AuthService {
  final String baseUrl = 'http://immy-database.czso7gvuv5td.eu-north-1.rds.amazonaws.com'; // Replace with your API URL
  // Token storage key
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  
  // Register a new user
  Future<User> register(String name, String email, String password) async {
    try {
      print("Attempting to register new user: $name, $email");
      
      // Standardize email (trim and lowercase) for consistency
      final standardizedEmail = email.trim().toLowerCase();
      print("Standardized email for registration: $standardizedEmail");
      
      // Check if user already exists
      final existingUser = await BackendApiService.getUserByEmail(standardizedEmail);
      if (existingUser != null) {
        print("User with email $standardizedEmail already exists");
        throw Exception('A user with this email already exists. Please login instead.');
      }
      
      // Try to create user in the database
      print("Creating new user in database");
      final userData = await BackendApiService.createUser(name, standardizedEmail, password);
      
      print("User created successfully with ID: ${userData['id']}");
      
      // Create a user object with a token
      final user = User(
        id: userData['id'],
        name: userData['name'],
        email: userData['email'],
        token: _generateToken(userData['id'].toString()),
        isAdmin: false,
      );
      
      print("User object created, saving locally");
      
      // Save user data locally
      await _saveUserData(user);
      return user;
    } catch (e) {
      print("Registration error: $e");
      
      // Special handling for administrator registration attempt
      if (email.trim().toLowerCase() == 'administrator') {
        print("Administrator registration attempted - using local admin login");
        return _checkLocalAdminLogin(email, password);
      }
      
      // Provide clear error message
      String errorMessage = e.toString();
      if (errorMessage.contains('DatabaseTimeoutException')) {
        errorMessage = 'Database connection timed out. Please try again.';
      } else if (!errorMessage.contains('already exists')) {
        errorMessage = 'Registration failed: $e';
      }
      
      throw Exception(errorMessage);
    }
  }
  
  // Login user
  Future<User> login(String email, String password) async {
    try {
      print("Attempting login with email: $email");
      
      // Special case for administrator login
      if (email.toLowerCase() == 'administrator' && password == 'admin') {
        print("Admin credentials detected, creating admin user");
        return _checkLocalAdminLogin(email, password);
      }
      
      // Special case for test user (for immediate testing)
      if (email.trim().toLowerCase() == 'test@example.com' && password == 'password123') {
        print("Test user login detected, creating test user");
        final testUser = User(
          id: 999,
          name: 'Test User',
          email: 'test@example.com',
          token: _generateToken('999'),
          isAdmin: false,
        );
        await _saveUserData(testUser);
        return testUser;
      }
      
      // Standardize email (trim and lowercase) for consistency
      final standardizedEmail = email.trim().toLowerCase();
      print("Standardized email for lookup: $standardizedEmail");
      
      // Try to get user from database
      print("Checking for user in database");
      final userData = await BackendApiService.getUserByEmail(standardizedEmail);
      
      if (userData == null) {
        print("User not found in database");
        
        // Only try local admin login if explicitly using administrator account
        if (standardizedEmail == 'administrator') {
          print("Falling back to local admin authentication");
          return _checkLocalAdminLogin(standardizedEmail, password);
        }
        
        throw Exception('User not found. Please check your email or register a new account.');
      }
      
      print("User found, checking password");
      print("Stored password: ${userData['password']}, Input password: $password");
      
      // In a real app, you would verify the password hash here
      if (userData['password'] != password) {
        print("Invalid password");
        throw Exception('Invalid password. Please try again.');
      }
      
      // Check if the user is marked as admin in the database
      bool isAdmin = userData['is_admin'] == 1 || userData['is_admin'] == true;
      print("User is admin: $isAdmin");
      
      // Create a user object with a token
      final user = User(
        id: userData['id'],
        name: userData['name'],
        email: userData['email'],
        token: _generateToken(userData['id'].toString()),
        isAdmin: isAdmin,
      );
      
      print("User created with isAdmin: ${user.isAdmin}");
      
      // Save user data locally
      await _saveUserData(user);
      return user;
    } catch (e) {
      print("Login error: $e");
      
      // If API call fails and it's the administrator, try local authentication
      if (email.toLowerCase() == 'administrator') {
        print("Falling back to local admin authentication");
        return _checkLocalAdminLogin(email, password);
      }
      
      // Provide clear error message
      String errorMessage = e.toString();
      if (errorMessage.contains('DatabaseTimeoutException')) {
        errorMessage = 'Database connection timed out. Please try again.';
      } else if (!errorMessage.contains('User not found') && !errorMessage.contains('Invalid password')) {
        errorMessage = 'Login failed: $e';
      }
      
      throw Exception(errorMessage);
    }
  }
  
  // Check local admin login
  Future<User> _checkLocalAdminLogin(String email, String password) async {
    print("Checking local admin login: $email / $password");
    
    if (email.toLowerCase() == 'administrator' && password == 'admin') {
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
      print("Invalid admin credentials");
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
    try {
      final user = await getCurrentUser();
      if (user == null) {
        print("No current user found in isCurrentUserAdmin");
        return false;
      }
      
      final isAdmin = user.isAdmin;
      print("Current user admin status from isCurrentUserAdmin: $isAdmin");
      return isAdmin;
    } catch (e) {
      print("Error checking admin status: $e");
      return false;
    }
  }
  
  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      
      if (userData == null || userData.isEmpty) {
        print("No user data found in shared preferences");
        return null;
      }
      
      try {
        final user = User.fromJson(jsonDecode(userData));
        print("Retrieved current user: ${user.name}, email: ${user.email}, isAdmin: ${user.isAdmin}");
        return user;
      } catch (e) {
        print("Error parsing user data: $e");
        // Try to recover by removing invalid data
        await prefs.remove(_userKey);
        await prefs.remove(_tokenKey);
        return null;
      }
    } catch (e) {
      print("Error retrieving user data: $e");
      return null;
    }
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


