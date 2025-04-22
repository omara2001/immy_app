import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'terms_and_conditions_page.dart';
import '../services/users_auth_service.dart' as user_auth;

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  bool _termsAccepted = false;
  final _authService = user_auth.AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset(
                'assets/immy_BrainyBear.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),
              const Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // blue-50
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Future Toys is a cloud based service provider, and processes and retains audio and other data to improve our services.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsAndConditionsPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Learn how Immy is designed to protect your privacy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1D4ED8), // blue-700
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    onChanged: (value) {
                      setState(() {
                        _termsAccepted = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF8B5CF6), // purple-600
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        'I acknowledge that I have read and understood the Terms of Service and Privacy Policy',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _termsAccepted && !_isLoading
                      ? () {
                          _handleTermsAccepted();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6), // purple-600
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    disabledBackgroundColor: const Color(0xFFD1D5DB), // gray-300
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Agree & Continue',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'By clicking "Agree & Continue", you confirm that you are a parent or guardian.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280), // gray-500
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTermsAccepted() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Save that user has accepted terms
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terms_accepted', true);
      
      if (!mounted) return;
      
      // Force users to login after accepting terms
      print("Terms accepted, going to login screen");
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print("Error handling terms acceptance: $e");
      // If there's any error, just go to the login screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}