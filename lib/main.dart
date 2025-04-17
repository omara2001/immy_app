import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/register_screen.dart';
import 'screens/terms_of_service_page.dart';
import 'screens/home_page.dart';
import 'screens/serial_management_screen.dart';
import 'screens/serial_lookup_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
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
    return MaterialApp(
      title: 'Immy App',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        primaryColor: const Color(0xFF8B5CF6), // purple-600
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
          primary: const Color(0xFF8B5CF6),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB), // gray-50
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8B5CF6), // purple-600
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE5E7EB)), // gray-200
          ),
        ),
        useMaterial3: true,
      ),
      // Define named routes for easy navigation
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
              authService: authService,
            ),
        '/admin/dashboard': (context) => AdminRouteGuard(
              authService: authService,
              child: AdminDashboardScreen(
                serialService: serialService,
                authService: authService,
              ),
            ),
        '/recent-conversations': (context) => RecentConversationsScreen(
              apiService: apiService,
              authService: authService,
            ),
        '/scan-qr-code': (context) => QrScannerScreen(
              serialService: serialService,
            ),
        '/device-management': (context) => DeviceManagementScreen(
              serialService: serialService,
            ),
      },
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
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
    
    try {
      // Check if user is logged in
      final isLoggedIn = await usersAuthService.isLoggedIn();
      
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
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}