import 'package:flutter/material.dart';
import '../models/serial_number.dart';
import '../models/user_profile.dart';
import '../services/serial_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SerialManagementScreen extends StatefulWidget {
  final SerialService serialService;

  const SerialManagementScreen({
    super.key,
    required this.serialService,
  });

  @override
  State<SerialManagementScreen> createState() => _SerialManagementScreenState();
}

class _SerialManagementScreenState extends State<SerialManagementScreen> {
  List<SerialNumber> _serials = [];
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load serials and users
      _serials = await widget.serialService.getSerialList();
      _users = await widget.serialService.getAllUsers();
      
      // If no data, initialize with sample data
      if (_serials.isEmpty || _users.isEmpty) {
        await widget.serialService.initWithSampleData();
        _serials = await widget.serialService.getSerialList();
        _users = await widget.serialService.getAllUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateSerials() async {
    final TextEditingController countController = TextEditingController(text: '1');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Serial Numbers'),
        content: TextField(
          controller: countController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of serials to generate',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final count = int.tryParse(countController.text) ?? 1;
              Navigator.pop(context);
              
              try {
                await widget.serialService.generateSerials(count);
                await _loadData();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Generated $count serial numbers')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error generating serials: $e')),
                  );
                }
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignSerial() async {
    if (_serials.isEmpty || _users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No serials or users available')),
      );
      return;
    }
    
    UserProfile? selectedUser;
    SerialNumber? selectedSerial;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Serial Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserProfile>(
                decoration: const InputDecoration(
                  labelText: 'Select User',
                ),
                value: selectedUser,
                items: _users.map((user) {
                  return DropdownMenuItem<UserProfile>(
                    value: user,
                    child: Text('${user.name} (${user.email})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedUser = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SerialNumber>(
                decoration: const InputDecoration(
                  labelText: 'Select Serial Number',
                ),
                value: selectedSerial,
                items: _serials
                    .where((serial) => serial.assignedToUserId == null)
                    .map((serial) {
                  return DropdownMenuItem<SerialNumber>(
                    value: serial,
                    child: Text(serial.serial),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSerial = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedUser != null && selectedSerial != null
                  ? () async {
                      Navigator.pop(context);
                      
                      try {
                        // Check if user already has a serial
                        final existingSerial = _serials.firstWhere(
                          (s) => s.assignedToUserId == selectedUser!.id,
                          orElse: () => SerialNumber(
                            id: '',
                            serial: '',
                            qrCodePath: '',
                          ),
                        );
                        
                        if (existingSerial.id.isNotEmpty) {
                          // User already has a serial, confirm replacement
                          final shouldReplace = await _confirmReplaceSerial(
                            selectedUser!,
                            existingSerial,
                            selectedSerial!,
                          );
                          
                          if (shouldReplace && mounted) {
                            await widget.serialService.replaceSerial(
                              selectedUser!,
                              selectedSerial!,
                            );
                            await _loadData();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Serial number replaced successfully')),
                            );
                          }
                        } else {
                          // User doesn't have a serial, assign directly
                          await widget.serialService.assignSerialToUser(
                            selectedUser!,
                            selectedSerial!,
                          );
                          await _loadData();
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Serial number assigned successfully')),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error assigning serial: $e')),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmReplaceSerial(
    UserProfile user,
    SerialNumber oldSerial,
    SerialNumber newSerial,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace Serial Number?'),
        content: Text(
          '${user.name} already has serial number ${oldSerial.serial}. '
          'Do you want to replace it with ${newSerial.serial}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Management'),
        backgroundColor: const Color(0xFF8B5CF6), // purple-600
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Serial Numbers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _generateSerials,
                            icon: const Icon(Icons.add),
                            label: const Text('Generate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6), // purple-600
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _assignSerial,
                            icon: const Icon(Icons.link),
                            label: const Text('Assign'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6), // purple-600
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _serials.isEmpty
                        ? const Center(
                            child: Text(
                              'No serial numbers available. Generate some to get started.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _serials.length,
                            itemBuilder: (context, index) {
                              final serial = _serials[index];
                              final assignedUser = serial.assignedToUserId != null
                                  ? _users.firstWhere(
                                      (user) => user.id == serial.assignedToUserId,
                                      orElse: () => UserProfile(
                                        id: '',
                                        name: 'Unknown',
                                        email: '',
                                        // No need to specify passwordHash as it's optional now
                                      ),
                                    )
                                  : null;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: QrImageView(
                                          data: serial.serial,
                                          version: QrVersions.auto,
                                          backgroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              serial.serial,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              assignedUser != null
                                                  ? 'Assigned to: ${assignedUser.name} (${assignedUser.email})'
                                                  : 'Not assigned',
                                              style: TextStyle(
                                                color: assignedUser != null
                                                    ? const Color(0xFF16A34A) // green-600
                                                    : const Color(0xFF6B7280), // gray-500
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
