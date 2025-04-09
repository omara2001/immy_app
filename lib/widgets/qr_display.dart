import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/serial_number.dart';

class QrDisplay extends StatelessWidget {
  final SerialNumber serialNumber;
  final double size;

  const QrDisplay({
    super.key,
    required this.serialNumber,
    this.size = 200.0,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the QR code image exists on disk
    final file = File(serialNumber.qrCodePath);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // If the file exists, display it, otherwise generate a new QR code
        file.existsSync()
            ? Image.file(
                file,
                width: size,
                height: size,
              )
            : QrImageView(
                data: serialNumber.serial,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
              ),
        const SizedBox(height: 16),
        Text(
          serialNumber.serial,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
