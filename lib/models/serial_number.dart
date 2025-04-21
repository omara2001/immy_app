class SerialNumber {
  final String id;
  final String serial;
  final String qrCodePath;
  String? assignedToUserId;
  final String status;

  SerialNumber({
    required this.id,
    required this.serial,
    required this.qrCodePath,
    this.assignedToUserId,
    required this.status,
  });

  // Convert to and from JSON for storage
  factory SerialNumber.fromJson(Map<String, dynamic> json) {
    return SerialNumber(
      id: json['id'],
      serial: json['serial'],
      qrCodePath: json['qrCodePath'],
      assignedToUserId: json['assignedToUserId'],
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serial': serial,
      'qrCodePath': qrCodePath,
      'assignedToUserId': assignedToUserId,
      'status': status,
    };
  }
}
