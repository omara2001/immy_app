import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/serial_number.dart';
import '../services/serial_service.dart';

class SerialInfoCard extends StatefulWidget {
  final String userEmail;
  final SerialService serialService;

  const SerialInfoCard({
    super.key,
    required this.userEmail,
    required this.serialService,
  });

  @override
  State<SerialInfoCard> createState() => _SerialInfoCardState();
}

class _SerialInfoCardState extends State<SerialInfoCard> {
  SerialNumber? _serialNumber;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSerialInfo();
  }

  Future<void> _loadSerialInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serial = await widget.serialService.getUserSerial(widget.userEmail);
      setState(() {
        _serialNumber = serial;
        if (serial == null) {
          _errorMessage = 'No serial number assigned to this account yet.';
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
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? _buildErrorView()
                : _buildSerialInfoView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Immy Bear Serial Number',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7), // amber-100
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFFD97706), // amber-600
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFF92400E), // amber-800
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/serial-management');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6), // purple-600
              foregroundColor: Colors.white,
            ),
            child: const Text('Manage Serial Numbers'),
          ),
        ),
      ],
    );
  }

  Widget _buildSerialInfoView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Immy Bear Serial Number',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              QrImageView(
                data: _serialNumber!.serial,
                version: QrVersions.auto,
                size: 150,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                _serialNumber!.serial,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan this code to pair with your Immy Bear',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280), // gray-500
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/serial-management');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6), // purple-600
              side: const BorderSide(color: Color(0xFF8B5CF6)), // purple-600
            ),
            child: const Text('Manage Serial Numbers'),
          ),
        ),
      ],
    );
  }
}