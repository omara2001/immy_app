import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/terms_of_service_page.dart';
import 'screens/home_page.dart';
import 'screens/serial_management_screen.dart';
import 'screens/serial_lookup_screen.dart';
import 'services/serial_service.dart';
import 'services/api_service.dart';

void main() {
  // Initialize services
  final serialService = SerialService();
  final apiService = ApiService();
  
  runApp(MyApp(
    serialService: serialService,
    apiService: apiService,
  ));
}

class MyApp extends StatelessWidget {
  final SerialService serialService;
  final ApiService apiService;
  
  const MyApp({
    super.key, 
    required this.serialService,
    required this.apiService,
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
        '/home': (context) => HomePage(
              serialService: serialService,
              apiService: apiService,
            ),
        '/terms': (context) => const TermsOfServicePage(),
        '/serial-management': (context) => SerialManagementScreen(
              serialService: serialService,
            ),
        '/serial-lookup': (context) => SerialLookupScreen(
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
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bool termsAccepted = prefs.getBool('terms_accepted') ?? false;

    if (!mounted) return;

    // Simulate a splash screen delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (termsAccepted) {
      // User has already accepted terms, go directly to home page
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // First time user, show terms of service
      Navigator.of(context).pushReplacementNamed('/terms');
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