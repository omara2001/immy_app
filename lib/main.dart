import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
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
import 'services/theme_provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'services/stripe_service.dart';
import 'services/payment_processor.dart';
import 'screens/subscription_screen.dart';
import 'dart:async';
import 'screens/conversation_detail_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/learning_journey_screen.dart';
import 'screens/story_time_screen.dart';
import 'services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().init();

  // Request notification permissions
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

  // Only initialize essential services for UI
  final serialService = SerialService();
  final apiService = ApiService();
  final adminAuthService = admin_auth.AuthService();
  final userAuthService = user_auth.AuthService();

  // Initialize Stripe early
  try {
    final publishableKey = 'pk_test_51R00wJP1l4vbhTn5ncEmkHyXbk0Csb22wsmqYsYbAssUvPIsR3dldovfgPlqsZzcf3LtIhrOKqAVWITKfYR2fFx600KQdXd1p2';

    // Initialize Stripe
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();

    // Initialize PaymentProcessor
    await PaymentProcessor.initialize(publishableKey);

    // Initialize Stripe service for backend operations
    StripeService.initialize(
      secretKey: 'sk_test_51R00wJP1l4vbhTn5Xfe5zWNZrVtHyA7EeP1REpL92RXarOtVRelDEPPHBNdvEdhWRFMd66CWmOLd2cCI2ZF6aAls00jM6x0sdT',
      publishableKey: publishableKey,
      testMode: false, // Using test keys in live mode
    );

    print('Stripe and PaymentProcessor initialized successfully with test keys');
  } catch (e) {
    print('Error initializing Stripe (will use mock data): $e');
    // Initialize in test mode anyway to ensure mocks work
    StripeService.initialize(
      secretKey: 'sk_test_mock',
      publishableKey: 'pk_test_mock',
      testMode: true,
    );
  }

  // Start the app immediately
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(
        serialService: serialService,
        apiService: apiService,
        authService: adminAuthService,
        usersAuthService: userAuthService,
      ),
    ),
  );

  // Initialize database and other services in the background
  Future.microtask(() async {
    // Initialize BackendApiService first
    try {
      await BackendApiService.initialize();
      print('Database connection initialized successfully');
    } catch (e) {
      print('Error initializing database connection: $e');
    }

    // Initialize admin users
    try {
      await adminAuthService.initializeAdminUser();
      print('Admin user initialized successfully');
    } catch (e) {
      print('Error initializing admin user: $e');
    }

    try {
      await userAuthService.initializeAdminUser();
      print('User admin initialized successfully');
    } catch (e) {
      print('Error initializing user admin: $e');
    }
  });
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Immy App',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
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
            ),
        '/scan-qr-code': (context) => QrScannerScreen(
              serialService: widget.serialService,
            ),
        '/device-management': (context) => DeviceManagementScreen(
              serialService: widget.serialService,
            ),
        '/subscription': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            // Handle case when no arguments are provided
            return const Scaffold(
              body: Center(
                child: Text('Error: Missing subscription information'),
              ),
            );
          }
          return SubscriptionScreen(
            userId: args['userId'],
          );
        },
        // Keep conversation detail screen accessible via deep linking
        '/conversation-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ConversationDetailScreen(
            apiService: widget.apiService,
            conversationId: args['conversationId'],
            authService: widget.authService,
          );
        },
        '/payment_history': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            // Handle case when no arguments are provided
            return const Scaffold(
              body: Center(
                child: Text('Error: Missing user information'),
              ),
            );
          }
          return PaymentHistoryScreen(
            userId: args['userId'],
          );
        },
        '/learning-journey': (context) => const LearningJourneyScreen(),
        '/story-time': (context) => const StoryTimeScreen(),
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
