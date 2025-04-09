import 'package:flutter/material.dart';
import '../models/serial_number.dart';
import '../services/serial_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SerialLookupScreen extends StatefulWidget {
  final SerialService serialService;

  const SerialLookupScreen({
    super.key,
    required this.serialService,
  });

  @override
  State<SerialLookupScreen> createState() => _SerialLookupScreenState();
}

class _SerialLookupScreenState extends State<SerialLookupScreen> {
  final TextEditingController _emailController = TextEditingController();
  SerialNumber? _serialNumber;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _lookupSerial() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _serialNumber = null;
    });

    try {
      final serial = await widget.serialService.getUserSerial(email);
      setState(() {
        _serialNumber = serial;
        if (serial == null) {
          _errorMessage = 'No serial number assigned to this user.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Lookup'),
        backgroundColor: const Color(0xFF8B5CF6), // purple-600
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Look up a user\'s serial number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _lookupSerial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6), // purple-600
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Look Up'),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2), // red-100
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)), // red-300
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444), // red-500
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C), // red-700
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_serialNumber != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Serial Number Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: _serialNumber!.serial,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _serialNumber!.serial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Assigned to: ${_emailController.text}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}