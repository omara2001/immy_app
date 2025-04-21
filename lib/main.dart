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
import 'package:flutter_stripe/flutter_stripe.dart';
import 'services/stripe_service.dart';
import 'screens/payment_screen.dart';
import 'screens/subscription_screen.dart';
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database connection
  Stripe.publishableKey = 'pk_test_your_publishable_key'; // Replace with your Stripe publishable key
  await Stripe.instance.applySettings();
  
  // Initialize Stripe service
  StripeService.initialize(
    secretKey: 'sk_test_your_secret_key', // Replace with your Stripe secret key
    publishableKey: Stripe.publishableKey,
  );
  try {
    await BackendApiService.initialize();
    print('Database connection initialized successfully');
  } catch (e) {
    print('Error initializing database connection: $e');
  }
  
  // Initialize services
  final serialService = SerialService();
  final apiService = ApiService();
  final adminAuthService = admin_auth.AuthService();
  final userAuthService = user_auth.AuthService();
  
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

class MyApp extends StatefulWidget {
  final SerialService serialService;
  final ApiService apiService;
  final admin_auth.AuthService authService;
  final user_auth.AuthService usersAuthService;
  
  const MyApp({
    super.key, 
    required this.serialService,
    required this.apiService,
    required this.authService,
    required this.usersAuthService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register the observer to listen for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Unregister the observer
    WidgetsBinding.instance.removeObserver(this);
    // Close database connection
    BackendApiService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Close database connection when app is terminated
      BackendApiService.close();
    }
  }

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
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomePage(
              serialService: widget.serialService,
              apiService: widget.apiService,
              authService: widget.authService,
              usersAuthService: widget.usersAuthService,
            ),
        '/terms': (context) => const TermsOfServicePage(),
        '/serial-management': (context) => SerialManagementScreen(
              serialService: widget.serialService,
            ),
        '/serial-lookup': (context) => SerialLookupScreen(
              serialService: widget.serialService,
            ),
        '/admin/login': (context) => AdminLoginScreen(
              authService: widget.authService,
            ),
        '/admin/dashboard': (context) => AdminDashboardScreen(
              serialService: widget.serialService,
              authService: widget.authService,
            ),
        '/recent-conversations': (context) => RecentConversationsScreen(
              apiService: widget.apiService,
              authService: widget.authService,
            ),
        '/scan-qr-code': (context) => QrScannerScreen(
              serialService: widget.serialService,
            ),
        '/device-management': (context) => DeviceManagementScreen(
              serialService: widget.serialService,
            ),
        '/payment': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PaymentScreen(
            userId: args['userId'],
            serialId: args['serialId'],
          );
        },
        '/subscription': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return SubscriptionScreen(
            userId: args['userId'],
          );
        },
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
        
        if (termsAccepted) {
          // User has already accepted terms, go directly to home page
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          // User is logged in but hasn't accepted terms
          Navigator.of(context).pushReplacementNamed('/terms');
        }
      } else {
        // User is not logged in, go to login page
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