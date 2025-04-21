import 'package:flutter/material.dart';
import '../services/serial_service.dart';
import '../services/backend_api_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart';

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
  List<Map<String, dynamic>> _serials = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  
  // Helper method to check if assigned_at column exists
  Future<bool> _hasAssignedAtColumn() async {
    if (kIsWeb) return true; // Assume column exists on web
    
    try {
      final columns = await BackendApiService.executeQuery(
        "SHOW COLUMNS FROM SerialNumbers LIKE 'assigned_at'");
      return columns.isNotEmpty;
    } catch (e) {
      print('Error checking column: $e');
      return false;
    }
  }

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
      // Load users directly from database
      final users = await BackendApiService.executeQuery('''
        SELECT id, name, email, is_admin, created_at
        FROM Users
        ORDER BY name
      ''');
      
      // Load serials with appropriate query based on column existence
      final hasAssignedAt = await _hasAssignedAtColumn();
      final serials = hasAssignedAt 
        ? await BackendApiService.executeQuery('''
            SELECT 
              s.id,
              s.serial,
              s.status,
              s.created_at,
              s.assigned_at,
              s.user_id,
              u.name as assigned_to_name,
              u.email as assigned_to_email
            FROM SerialNumbers s
            LEFT JOIN Users u ON s.user_id = u.id
            ORDER BY s.created_at DESC
          ''')
        : await BackendApiService.executeQuery('''
            SELECT 
              s.id,
              s.serial,
              s.status,
              s.created_at,
              s.user_id,
              u.name as assigned_to_name,
              u.email as assigned_to_email
            FROM SerialNumbers s
            LEFT JOIN Users u ON s.user_id = u.id
            ORDER BY s.created_at DESC
          ''');

      if (mounted) {
        setState(() {
          _serials = serials;
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
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
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final serials = List.generate(count, (_) {
                  final random = '${DateTime.now().year}-${_generateRandomString(6)}';
                  return 'IMMY-$random';
                });

                await BackendApiService.createQRCodes(serials);
                
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
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to generate random string for serial numbers
  String _generateRandomString(int length) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(length, (_) => chars[DateTime.now().millisecond % chars.length]).join();
  }

  Future<void> _assignSerial() async {
    if (_serials.isEmpty || _users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No serials or users available')),
      );
      return;
    }
    
    Map<String, dynamic>? selectedUser;
    Map<String, dynamic>? selectedSerial;
    
    // Get available (unassigned) serials
    final availableSerials = _serials.where((s) => s['user_id'] == null).toList();
    
    if (availableSerials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available serial numbers. Generate more to assign.')),
      );
      return;
    }
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Serial Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: 'Select User',
                ),
                value: selectedUser,
                items: _users.map((user) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: user,
                    child: Text('${user['name']} (${user['email']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedUser = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: 'Select Serial Number',
                ),
                value: selectedSerial,
                items: availableSerials.map((serial) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: serial,
                    child: Text(serial['serial']),
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
              onPressed: (selectedUser != null && selectedSerial != null)
                  ? () async {
                      Navigator.pop(context);
                      
                      setState(() {
                        _isLoading = true;
                      });
                      
                      try {
                        // Check if user already has a serial
                        final existingSerials = _serials.where(
                          (s) => s['user_id'] == selectedUser!['id']
                        ).toList();
                        
                        if (existingSerials.isNotEmpty) {
                          // User already has a serial, confirm replacement
                          final shouldReplace = await _confirmReplaceSerial(
                            selectedUser!,
                            existingSerials.first,
                            selectedSerial!,
                          );
                          
                          if (shouldReplace && mounted) {
                            // Unassign old serial
                            await BackendApiService.executeQuery('''
                              UPDATE SerialNumbers 
                              SET user_id = NULL, 
                                  status = 'active'
                              WHERE user_id = ?
                            ''', [selectedUser!['id']]);
                            
                            // Assign new serial
                            await BackendApiService.assignQRCodeToUser(
                              selectedSerial!['id'],
                              selectedUser!['id']
                            );
                            
                            await _loadData();
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Serial number replaced successfully')),
                              );
                            }
                          } else {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        } else {
                          // User doesn't have a serial, assign directly
                          await BackendApiService.assignQRCodeToUser(
                            selectedSerial!['id'],
                            selectedUser!['id']
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
                          setState(() {
                            _isLoading = false;
                          });
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
    Map<String, dynamic> user,
    Map<String, dynamic> oldSerial,
    Map<String, dynamic> newSerial,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace Serial Number?'),
        content: Text(
          '${user['name']} already has serial number ${oldSerial['serial']}. '
          'Do you want to replace it with ${newSerial['serial']}?',
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
                              final hasUser = serial['user_id'] != null;
                              
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
                                          data: serial['serial'],
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
                                              serial['serial'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              serial['assigned_to_name'] != null
                                                  ? 'Assigned to: ${serial['assigned_to_name']} (${serial['assigned_to_email']})'
                                                  : 'Not assigned',
                                              style: TextStyle(
                                                color: serial['assigned_to_name'] != null
                                                    ? const Color(0xFF16A34A) // green-600
                                                    : const Color(0xFF6B7280), // gray-500
                                              ),
                                            ),
                                            if (serial.containsKey('assigned_at') && serial['assigned_at'] != null) 
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text(
                                                  'Assigned on: ${serial['assigned_at']}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF6B7280), // gray-500
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          hasUser ? Icons.link_off : Icons.link,
                                          color: hasUser 
                                            ? const Color(0xFFEF4444) // red-500
                                            : const Color(0xFF8B5CF6), // purple-600
                                        ),
                                        onPressed: hasUser 
                                          ? () => _unassignSerial(serial) 
                                          : () => _quickAssignSerial(serial),
                                        tooltip: hasUser ? 'Unassign' : 'Assign',
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
  
  // Quick assign serial to a user
  Future<void> _quickAssignSerial(Map<String, dynamic> serial) async {
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No users available')),
      );
      return;
    }
    
    Map<String, dynamic>? selectedUser;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign QR Code'),
        content: DropdownButtonFormField<Map<String, dynamic>>(
          decoration: const InputDecoration(
            labelText: 'Select User',
          ),
          value: selectedUser,
          items: _users.map((user) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: user,
              child: Text('${user['name']} (${user['email']})'),
            );
          }).toList(),
          onChanged: (value) {
            selectedUser = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (selectedUser != null) {
                Navigator.pop(context, selectedUser);
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    ).then((selectedUser) async {
      if (selectedUser != null) {
        setState(() {
          _isLoading = true;
        });
        
        try {
          // Check if user already has a serial
          final existingSerials = _serials.where(
            (s) => s['user_id'] == selectedUser['id']
          ).toList();
          
          if (existingSerials.isNotEmpty) {
            // User already has a serial, confirm replacement
            final shouldReplace = await _confirmReplaceSerial(
              selectedUser,
              existingSerials.first,
              serial,
            );
            
            if (shouldReplace) {
              // Unassign old serial
              await BackendApiService.executeQuery('''
                UPDATE SerialNumbers 
                SET user_id = NULL, 
                    status = 'active'
                WHERE user_id = ?
              ''', [selectedUser['id']]);
              
              // Assign new serial
              await BackendApiService.assignQRCodeToUser(
                serial['id'],
                selectedUser['id']
              );
              
              await _loadData();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Serial number replaced successfully')),
                );
              }
            } else {
              setState(() {
                _isLoading = false;
              });
            }
          } else {
            // User doesn't have a serial, assign directly
            await BackendApiService.assignQRCodeToUser(
              serial['id'],
              selectedUser['id']
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
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    });
  }
  
  // Unassign a serial from a user
  Future<void> _unassignSerial(Map<String, dynamic> serial) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign QR Code'),
        content: Text(
          'Are you sure you want to unassign this QR code (${serial['serial']}) from ${serial['assigned_to_name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        await BackendApiService.executeQuery('''
          UPDATE SerialNumbers 
          SET user_id = NULL, 
              status = 'active'
          WHERE id = ?
        ''', [serial['id']]);
        
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR code unassigned successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error unassigning QR code: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}