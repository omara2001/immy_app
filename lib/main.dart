import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/user_profile.dart';
import 'models/user.dart';
import 'services/serial_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart' as admin_auth;
import 'services/users_auth_service.dart' as user_auth;
import 'screens/splash_screen.dart';
import 'screens/terms_of_service_page.dart';
import 'screens/home_page.dart';
import 'screens/serial_management_screen.dart';
import 'screens/serial_lookup_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/recent_conversations_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/device_management_screen.dart';
import 'services/serial_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart' as admin_auth;
import 'services/users_auth_service.dart' as user_auth;
import 'services/backend_api_service.dart'; 

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final serialService = SerialService();
  final apiService = ApiService();
  final adminAuthService = admin_auth.AuthService();
  final userAuthService = user_auth.AuthService();
  
  // Initialize database
  try {
    await BackendApiService.initializeDatabase();
    debugPrint('Database initialized successfully');
  } catch (e) {
    debugPrint('Error initializing database: $e');
  }
  
  // Initialize admin users
  await adminAuthService.initializeAdminUser();
  await userAuthService.initializeAdminUser();
  
  runApp(MyApp(
    serialService: serialService,
    apiService: apiService,
    authService: adminAuthService, 
    usersAuthService: userAuthService,
  ));
}

// Wrapper for admin-only screens
class AdminRouteGuard extends StatelessWidget {
  final Widget child;
  final admin_auth.AuthService authService;

  const AdminRouteGuard({
    Key? key,
    required this.child,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: authService.isCurrentUserAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isAdmin = snapshot.data ?? false;
        if (!isAdmin) {
          // Return to login page if not admin
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access denied: Admin privileges required')),
            );
            Navigator.of(context).pushReplacementNamed('/admin/login');
          });
          return const Scaffold(
            body: Center(
              child: Text('Access denied. Redirecting to login...'),
            ),
          );
        }

        // User is admin, show the protected screen
        return child;
      },
    );
  }
}

// Wrapper for admin-only screens
class AdminRouteGuard extends StatelessWidget {
  final Widget child;
  final admin_auth.AuthService authService;

  const AdminRouteGuard({
    Key? key,
    required this.child,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: authService.isCurrentUserAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isAdmin = snapshot.data ?? false;
        if (!isAdmin) {
          // Return to login page if not admin
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access denied: Admin privileges required')),
            );
            Navigator.of(context).pushReplacementNamed('/admin/login');
          });
          return const Scaffold(
            body: Center(
              child: Text('Access denied. Redirecting to login...'),
            ),
          );
        }

        // User is admin, show the protected screen
        return child;
      },
    );
  }
}

class MyApp extends StatelessWidget {
  final SerialService serialService;
  final ApiService apiService;
  final admin_auth.AuthService authService;
  final user_auth.AuthService usersAuthService;
  
  const MyApp({
    super.key, 
    required this.serialService,
    required this.apiService,
    required this.authService, required this.usersAuthService,
  });

  @override
  Widget build(BuildContext context) {
    // Initialize services
    final serialService = SerialService();
    final apiService = ApiService();

    return MaterialApp(
      title: 'Immy App',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomePage(
              serialService: serialService,
              apiService: apiService,
              authService: authService,
              usersAuthService: usersAuthService,
            ),
        '/terms': (context) => const TermsOfServicePage(),
        '/serial-management': (context) => SerialManagementScreen(
              serialService: serialService,
            ),
        '/serial-lookup': (context) => SerialLookupScreen(
              serialService: serialService,
            ),
        '/admin/login': (context) => AdminLoginScreen(
              authService: adminAuthService,
            ),
        '/admin/dashboard': (context) => AdminRouteGuard(
              authService: authService,
              child: AdminDashboardScreen(
                serialService: serialService,
                authService: authService,
              ),
            ),
        '/admin-setup': (context) => AdminSetupScreen(
              authService: adminAuthService,
            ),
      },
    );
  }
}

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
    // Simulate a splash screen delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final userAuth = user_auth.AuthService();
    final isLoggedIn = await userAuth.isLoggedIn();

    if (isLoggedIn) {
      // Check if user is admin
      final isAdmin = await userAuth.isCurrentUserAdmin();
      
      if (!mounted) return;
      
      if (isLoggedIn) {
        // Check if terms are accepted
        final prefs = await SharedPreferences.getInstance();
        final bool termsAccepted = prefs.getBool('terms_accepted') ?? false;
        
        if (!mounted) return;
        
        if (termsAccepted) {
          // User has already accepted terms, go directly to home page
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          // User is logged in but hasn't accepted terms
          Navigator.of(context).pushReplacementNamed('/terms');
        }
      } else {
        // User is not logged in, go to login page
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      // If there's an error, default to login page
      if (mounted) {
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