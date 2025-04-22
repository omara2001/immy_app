// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/users_auth_service.dart' as user_auth;
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final usersAuthService = user_auth.AuthService();
  
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Start loading the SharedPreferences early as it can be slow
    final prefsCompleter = Completer<SharedPreferences>();
    SharedPreferences.getInstance().then(
      (prefs) => prefsCompleter.complete(prefs),
      onError: (e) {
        print('Error loading SharedPreferences: $e');
        prefsCompleter.completeError(e);
      }
    );
    
    // Shorter splash screen delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    
    // Add a safety timeout to ensure the app doesn't hang
    bool authCheckComplete = false;
    
    // Set up a safety timeout (reduced to 3 seconds)
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || authCheckComplete) return;
      print("Auth check timeout - defaulting to login screen");
      Navigator.of(context).pushReplacementNamed('/login');
    });

    try {
      // Get SharedPreferences first
      final prefs = await prefsCompleter.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print("SharedPreferences timeout");
          throw TimeoutException("SharedPreferences timeout");
        }
      );
      
      // Check if this is the first time the app is running
      final firstRun = prefs.getBool('first_run') ?? true;
      if (firstRun) {
        print("First run detected, showing terms of service");
        if (mounted) {
          authCheckComplete = true;
          // Save that we've shown terms of service but don't mark as accepted yet
          await prefs.setBool('first_run', false);
          Navigator.of(context).pushReplacementNamed('/terms');
          return;
        }
      }
      
      // Check if terms have been accepted
      final termsAccepted = prefs.getBool('terms_accepted') ?? false;
      if (!termsAccepted) {
        print("Terms not accepted, showing terms of service");
        if (mounted) {
          authCheckComplete = true;
          Navigator.of(context).pushReplacementNamed('/terms');
          return;
        }
      }
      
      // For the initial flow, always force users to login after splash screen
      // to ensure the correct authentication
      authCheckComplete = true;
      print("Routing to login screen from splash");
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print('Error in splash screen: $e');
      // If there's an error, default to login page
      if (mounted && !authCheckComplete) {
        authCheckComplete = true;
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/immy_BrainyBear.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24),
            const Text(
              'Immy App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}