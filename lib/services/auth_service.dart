import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../utils/password_util.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static const String _currentUserKey = 'current_user';
  static const String _userProfilesKey = 'user_profiles';
  
  // Get the currently logged in user
  Future<UserProfile?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    
    if (userJson == null) {
      return null;
    }
    
    return UserProfile.fromJson(jsonDecode(userJson));
  }
  
  // Check if the current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    final currentUser = await getCurrentUser();
    final isAdmin = currentUser?.isAdmin ?? false;
    debugPrint("Admin auth service - isCurrentUserAdmin: $isAdmin");
    return isAdmin;
  }
  
  // Login with email and password
  Future<UserProfile?> login(String email, String password) async {
    debugPrint("Admin auth service - login attempt: $email");
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_userProfilesKey);
    
    if (profilesJson == null) {
      // If no profiles exist, create the admin user
      if (email == 'administrator' && password == 'admin') {
        return await createAdminUser('Administrator', 'administrator', 'admin');
      }
      return null;
    }
    
    final List<dynamic> decoded = jsonDecode(profilesJson);
    final profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
    
    // Find user by email
    final matchingUsers = profiles.where((profile) => profile.email == email).toList();
    if (matchingUsers.isEmpty) {
      // If no matching user but it's the admin credentials, create admin
      if (email == 'administrator' && password == 'admin') {
        return await createAdminUser('Administrator', 'administrator', 'admin');
      }
      return null;
    }
    
    final user = matchingUsers.first;
    
    // Verify password if hash exists
    if (user.passwordHash != null) {
      if (!PasswordUtil.verifyPassword(password, user.passwordHash!)) {
        throw Exception('Invalid password');
      }
    }
    
    // Save current user
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    debugPrint("Admin auth service - logged in user: ${user.name}, isAdmin: ${user.isAdmin}");
    
    return user;
  }
  
  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }
  
  // Set a user as admin (this would typically be done by another admin)
  Future<void> setUserAsAdmin(String userId, bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_userProfilesKey);
    
    if (profilesJson == null) {
      throw Exception('No user profiles found');
    }
    
    final List<dynamic> decoded = jsonDecode(profilesJson);
    final profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
    
    // Find user by ID
    final index = profiles.indexWhere((profile) => profile.id == userId);
    if (index == -1) {
      throw Exception('User not found');
    }
    
    // Update admin status
    profiles[index].isAdmin = isAdmin;
    
    // Save updated profiles
    await prefs.setString(_userProfilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    
    // If this is the current user, update current user as well
    final currentUser = await getCurrentUser();
    if (currentUser != null && currentUser.id == userId) {
      currentUser.isAdmin = isAdmin;
      await prefs.setString(_currentUserKey, jsonEncode(currentUser.toJson()));
    }
  }

  // Create an admin user (for first-time setup)
  Future<UserProfile> createAdminUser(String name, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_userProfilesKey);
    
    List<UserProfile> profiles = [];
    if (profilesJson != null) {
      final List<dynamic> decoded = jsonDecode(profilesJson);
      profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
      
      // Check if email already exists
      if (profiles.any((profile) => profile.email == email)) {
        // If admin already exists, just return it
        final existingAdmin = profiles.firstWhere((profile) => profile.email == email);
        
        // Make sure the existing administrator account has admin privileges
        if (email == 'administrator' && !existingAdmin.isAdmin) {
          existingAdmin.isAdmin = true;
          await prefs.setString(_userProfilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
          debugPrint("Fixing administrator account privileges: set to admin");
        }
        
        if (existingAdmin.isAdmin) {
          await prefs.setString(_currentUserKey, jsonEncode(existingAdmin.toJson()));
          debugPrint("Admin user already exists, returning existing admin");
          return existingAdmin;
        }
        throw Exception('A user with this email already exists');
      }
    }
    
    // Hash the password
    final passwordHash = PasswordUtil.hashPassword(password);
    
    // Create new admin profile
    final uuid = const Uuid();
    final newProfile = UserProfile(
      id: uuid.v4(),
      name: name,
      email: email,
      isAdmin: true, // Set as admin
      passwordHash: passwordHash,
    );
    
    debugPrint("Creating new admin user: ${newProfile.name}, isAdmin: ${newProfile.isAdmin}");
    
    // Add to list and save
    profiles.add(newProfile);
    await prefs.setString(_userProfilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    
    // Set as current user
    await prefs.setString(_currentUserKey, jsonEncode(newProfile.toJson()));
    
    return newProfile;
  }
  
  // Change user password
  Future<void> changePassword(String userId, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_userProfilesKey);
    
    if (profilesJson == null) {
      throw Exception('No user profiles found');
    }
    
    final List<dynamic> decoded = jsonDecode(profilesJson);
    final profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
    
    // Find user by ID
    final index = profiles.indexWhere((profile) => profile.id == userId);
    if (index == -1) {
      throw Exception('User not found');
    }
    
    // Update password hash
    profiles[index].passwordHash = PasswordUtil.hashPassword(newPassword);
    
    // Save updated profiles
    await prefs.setString(_userProfilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    
    // If this is the current user, update current user as well
    final currentUser = await getCurrentUser();
    if (currentUser != null && currentUser.id == userId) {
      currentUser.passwordHash = profiles[index].passwordHash;
      await prefs.setString(_currentUserKey, jsonEncode(currentUser.toJson()));
    }
  }
  
  // Initialize the admin user if it doesn't exist
  Future<void> initializeAdminUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_userProfilesKey);
      
      if (profilesJson == null) {
        // No profiles exist, create admin
        await createAdminUser('Administrator', 'administrator', 'admin');
        return;
      }
      
      final List<dynamic> decoded = jsonDecode(profilesJson);
      final profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
      
      // Check if admin exists
      final adminExists = profiles.any((profile) => 
        profile.email == 'administrator' && profile.isAdmin);
      
      // Create or fix the administrator account
      if (!adminExists) {
        // If 'administrator' exists but without admin privileges, update it
        final index = profiles.indexWhere((profile) => profile.email == 'administrator');
        if (index >= 0) {
          profiles[index].isAdmin = true;
          await prefs.setString(_userProfilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
          debugPrint("Fixed administrator account: granted admin privileges");
          return;
        }
        
        // Otherwise create a new administrator account
        await createAdminUser('Administrator', 'administrator', 'admin');
      }
    } catch (e) {
      debugPrint("Error initializing admin user: $e");
    }
  }
  
  // Get user by ID
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_userProfilesKey);
      
      if (profilesJson == null) {
        throw Exception('No user profiles found');
      }
      
      final List<dynamic> decoded = jsonDecode(profilesJson);
      final profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
      
      // Find user by ID
      final matchingUser = profiles.firstWhere(
        (profile) => profile.id == userId.toString(),
        orElse: () => throw Exception('User not found'),
      );
      
      return {
        'id': matchingUser.id,
        'name': matchingUser.name,
        'email': matchingUser.email,
        'is_admin': matchingUser.isAdmin,
      };
    } catch (e) {
      debugPrint("Error fetching user by ID: $e");
      return null;
    }
  }
}
