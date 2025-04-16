import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/serial_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart' as admin_auth;
import 'services/users_auth_service.dart' as user_auth;
import 'screens/terms_of_service_page.dart';
import 'screens/home_page.dart';
import 'screens/serial_management_screen.dart';
import 'screens/serial_lookup_screen.dart';
import 'screens/recent_conversations_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/device_management_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final adminAuthService = admin_auth.AuthService();
  final userAuthService = user_auth.AuthService();
  
  // Initialize admin users
  await adminAuthService.initializeAdminUser();
  await userAuthService.initializeAdminUser();
  
  runApp(MyApp(
    adminAuthService: adminAuthService,
    userAuthService: userAuthService, serialService: null, apiService: null,
  ));
}

class MyApp extends StatelessWidget {
  final admin_auth.AuthService adminAuthService;
  final user_auth.AuthService userAuthService;
  
  const MyApp({
    super.key,
    required this.adminAuthService,
    required this.userAuthService, required serialService, required apiService,
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
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomePage(
              serialService: serialService,
              apiService: apiService,
              authService: adminAuthService,
              usersAuthService: userAuthService,
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
        '/admin/dashboard': (context) => AdminDashboardScreen(
              serialService: serialService,
              authService: adminAuthService,
            ),
        '/admin-setup': (context) => AdminSetupScreen(
              authService: adminAuthService,
            ),
            '/recent-conversations': (context) => RecentConversationsScreen(
              apiService: apiService,
              usersAuthService: userAuthService,
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
    backgroundColor: const Color(0xFF8B5CF6), // purple-600 (same as first widget)
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
