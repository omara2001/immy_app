// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/users_auth_service.dart' as user_auth;
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Simulate a splash screen delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Import the user_auth service
    // You'll need to add this import at the top of the file
    // import '../services/users_auth_service.dart' as user_auth;
    final userAuth = user_auth.AuthService();
    final isLoggedIn = await userAuth.isLoggedIn();

    if (isLoggedIn) {
      // Check if user is admin
      final isAdmin = await userAuth.isCurrentUserAdmin();
      
      if (isAdmin) {
        // If admin, go to admin dashboard
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
      } else {
        // If regular user, go to home
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      // Not logged in, check if terms accepted
      final prefs = await SharedPreferences.getInstance();
      final bool termsAccepted = prefs.getBool('terms_accepted') ?? false;

      if (!termsAccepted) {
        // First time user, show terms of service
        Navigator.of(context).pushReplacementNamed('/terms');
      } else {
        // Terms accepted but not logged in, go to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8B5CF6), // purple-600
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or app icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'IA',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6), // purple-600
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}