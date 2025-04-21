import 'package:flutter/material.dart';
import '../services/serial_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/backend_api_service.dart';
import 'package:flutter/foundation.dart';

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
  Map<String, dynamic>? _qrCodeData;
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
      _qrCodeData = null;
    });

    try {
      // First search for the user
      final users = await BackendApiService.executeQuery('''
        SELECT id, name, email 
        FROM Users 
        WHERE email = ?
      ''', [email]);

      if (users.isEmpty) {
        setState(() {
          _errorMessage = 'No user found with this email address.';
        });
        return;
      }

      final user = users.first;
      
      // Log for debugging
      print('Found user: ${user['name']} (ID: ${user['id']})');
      
      // Check if assigned_at column exists in the SerialNumbers table
      List<Map<String, dynamic>> columns = [];
      if (!kIsWeb) {
        columns = await BackendApiService.executeQuery(
          "SHOW COLUMNS FROM SerialNumbers LIKE 'assigned_at'");
      }
      
      // Then get their QR code with appropriate query, focusing on user_id rather than status
      List<Map<String, dynamic>> qrCodes;
      if (columns.isEmpty && !kIsWeb) {
        // If assigned_at doesn't exist
        qrCodes = await BackendApiService.executeQuery('''
          SELECT 
            s.id,
            s.serial,
            s.status,
            s.created_at,
            u.name as assigned_to_name,
            u.email as assigned_to_email
          FROM SerialNumbers s
          JOIN Users u ON s.user_id = u.id
          WHERE s.user_id = ?
        ''', [user['id']]);
      } else {
        // If assigned_at exists or we're on web
        qrCodes = await BackendApiService.executeQuery('''
          SELECT 
            s.id,
            s.serial,
            s.status,
            s.created_at,
            s.assigned_at,
            u.name as assigned_to_name,
            u.email as assigned_to_email
          FROM SerialNumbers s
          JOIN Users u ON s.user_id = u.id
          WHERE s.user_id = ?
        ''', [user['id']]);
      }
      
      // Log for debugging
      print('Found ${qrCodes.length} QR codes for user ${user['name']}');
      
      // If still no QR codes found, try a more lenient query
      if (qrCodes.isEmpty) {
        // Try an alternative query that only relies on the user_id in SerialNumbers
        qrCodes = await BackendApiService.executeQuery('''
          SELECT 
            s.id,
            s.serial,
            s.status,
            s.created_at,
            u.name as assigned_to_name,
            u.email as assigned_to_email
          FROM SerialNumbers s
          JOIN Users u ON u.id = ?
          WHERE s.user_id = ?
        ''', [user['id'], user['id']]);
        
        print('Alternative query found ${qrCodes.length} QR codes for user ${user['name']}');
      }

      setState(() {
        if (qrCodes.isEmpty) {
          _errorMessage = 'No QR code assigned to this user.';
        } else {
          _qrCodeData = qrCodes.first;
        }
      });
    } catch (e) {
      print('Error during lookup: $e');
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
        title: const Text('QR Code Lookup'),
        backgroundColor: const Color(0xFF8B5CF6), // purple-600
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Look up a user\'s QR code',
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
            if (_qrCodeData != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QR Code Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Add a refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _lookupSerial,
                    tooltip: 'Refresh QR code data',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)), // gray-200
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: _qrCodeData!['serial'] ?? 'Invalid QR Code',
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard('Serial Number', _qrCodeData!['serial'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoCard('Status', _qrCodeData!['status'] ?? 'Active'),
              const SizedBox(height: 8),
              _buildInfoCard('Assigned To', '${_qrCodeData!['assigned_to_name'] ?? 'N/A'} (${_qrCodeData!['assigned_to_email'] ?? 'N/A'})'),
              const SizedBox(height: 8),
              _buildInfoCard('Assigned On', _getAssignmentDate()),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper widget for info cards
  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // gray-50
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)), // gray-200
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280), // gray-500
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to get the assignment date text
  String _getAssignmentDate() {
    if (_qrCodeData == null) return 'N/A';
    
    if (_qrCodeData!.containsKey('assigned_at') && _qrCodeData!['assigned_at'] != null) {
      return _qrCodeData!['assigned_at'].toString();
    } 
    
    // Fallback to created_at if assigned_at is not available
    if (_qrCodeData!.containsKey('created_at') && _qrCodeData!['created_at'] != null) {
      return _qrCodeData!['created_at'].toString();
    }
    
    return 'N/A';
  }
}