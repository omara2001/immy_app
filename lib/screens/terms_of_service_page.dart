import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'terms_and_conditions_page.dart';

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  bool _termsAccepted = false;

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
                  onPressed: _termsAccepted
                      ? () {
                          _showTermsAcceptedDialog();
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
                  child: const Text(
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

  void _showTermsAcceptedDialog() async {
    // Save that user has accepted terms
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms accepted!'),
        content: const Text('Proceeding to Immy app.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}