import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

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
    return currentUser?.isAdmin ?? false;
  }
  
  // Login with email
  Future<UserProfile?> login(String email, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_userProfilesKey);
    
    if (profilesJson == null) {
      return null;
    }
    
    final List<dynamic> decoded = jsonDecode(profilesJson);
    final profiles = decoded.map((json) => UserProfile.fromJson(json)).toList();
    
    // Find user by email
    final matchingUsers = profiles.where((profile) => profile.email == email).toList();
    if (matchingUsers.isEmpty) {
      return null;
    }
    
    final user = matchingUsers.first;
    
    // Save current user
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    
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
}
