import 'package:flutter/material.dart';
import 'package:immy_app/models/user_profile.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/serial_service.dart';
import '../services/qr_scanner_service.dart';
import '../models/serial_number.dart';
import '../services/backend_api_service.dart';

import '../services/users_auth_service.dart' as user_auth;

class QrScannerScreen extends StatefulWidget {
  final SerialService serialService;

  const QrScannerScreen({
    super.key,
    required this.serialService,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  late QrScannerService _qrScannerService;
  bool _isProcessing = false;
  String? _lastScanned;

  @override
  void initState() {
    super.initState();
    _qrScannerService = QrScannerService(widget.serialService);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processScannedCode(String code) async {
  if (_isProcessing || code == _lastScanned) return;

  setState(() {
    _isProcessing = true;
    _lastScanned = code;
  });

  try {
    // ✅ 1. Get current user
    final user = await user_auth.AuthService().getCurrentUser();

    if (user == null) {
      if (mounted) {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    // ✅ 2. Check subscription
    final isSubscribed = await user_auth.AuthService().isUserSubscribed(user.id);

    if (!isSubscribed) {
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/subscription',
          arguments: {'userId': user.id},
        );
      }
      return;
    }

    // ✅ 3. Process scanned code
    final result = await _qrScannerService.processScannedCode(code);

    // ✅ 4. Save recent scan
    await _qrScannerService.saveRecentScan(code);

    if (mounted) {
      if (result['success']) {
        final SerialNumber serial = result['serial'];

        // ✅ 5. Get full user data from backend
        final userMap = await BackendApiService.getUserByEmail(user.email);
        if (userMap == null) {
          throw Exception('User not found in database');
        }

        final userProfile = UserProfile(
          id: userMap['id'].toString(),
          email: userMap['email'],
          name: userMap['name'],
        );

        // ✅ 6. Assign serial
        await widget.serialService.assignSerialToUser(userProfile, serial);

        // ✅ 7. Show success dialog
        await _showResultDialog(
          title: 'Valid Immy Bear',
          message: result['message'],
          isSuccess: true,
          serial: serial,
          isAssigned: result['isAssigned'],
        );
      } else {
        // ❌ Invalid QR
        await _showResultDialog(
          title: 'Invalid QR Code',
          message: result['message'],
          isSuccess: false,
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing QR code: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

  Future<void> _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
    SerialNumber? serial,
    bool isAssigned = false,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (isSuccess && serial != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Serial Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Serial: ${serial.serial}'),
              Text('Status: ${isAssigned ? 'Assigned' : 'Unassigned'}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (isSuccess && serial != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/device-management',
                );
              },
              child: const Text('Manage Devices'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.white);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.white);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front, color: Colors.white);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear, color: Colors.white);
                  default:
                    return const Icon(Icons.camera_rear, color: Colors.white);
                }
              },
            ),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _processScannedCode(barcode.rawValue!);
                  }
                }
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.7),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan your Immy Bear QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Position the QR code within the scanner frame to register or manage your Immy Bear.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on MobileScannerController {
  get cameraFacingState => null;
  
  get torchState => null;
}
