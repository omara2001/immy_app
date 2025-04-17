import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  final AuthService authService;
  
  const AdminLoginScreen({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  _AdminLoginScreenState createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController(text: 'administrator');
  final _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validate inputs first
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Force administrator login
    if (email != 'administrator') {
      setState(() {
        _errorMessage = 'Only the administrator account can access this panel';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await widget.authService.login(email, password);
      
      if (user == null) {
        setState(() {
          _errorMessage = 'Invalid administrator credentials';
          _isLoading = false;
        });
        return;
      }
      
      if (!user.isAdmin) {
        setState(() {
          _errorMessage = 'Access denied: Admin privileges required';
          _isLoading = false;
        });
        return;
      }
      
      // Navigate to admin dashboard on successful login
      if (mounted) {
        // Return true to indicate successful login
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
        // Also pop with result for cases where we're using push instead of pushReplacement
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Administrator Access Only',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only the administrator account can access this panel',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              enabled: false, // Only allow administrator login
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'administrator',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Login as Administrator'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
