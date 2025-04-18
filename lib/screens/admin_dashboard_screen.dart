import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';
import '../services/auth_service.dart';
import '../services/serial_service.dart';
import '../models/user_profile.dart';

class AdminDashboardScreen extends StatefulWidget {
  final SerialService serialService;
  final AuthService authService;

  const AdminDashboardScreen({
    Key? key,
    required this.serialService,
    required this.authService,
  }) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _qrCodes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await widget.authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await AdminDashboardService.getRegisteredUsers();
      final qrCodes = await AdminDashboardService.getAllQRCodes();
      
      if (mounted) {
        setState(() {
          _users = users;
          _qrCodes = qrCodes;
        });
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

  Future<void> _searchUsers() async {
    if (_searchQuery.isEmpty) {
      await _loadData();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await AdminDashboardService.searchUsers(_searchQuery);
      setState(() {
        _users = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateQRCodes() async {
    final TextEditingController countController = TextEditingController(text: '1');
    
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate QR Codes'),
        content: TextField(
          controller: countController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of QR codes to generate',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final count = int.tryParse(countController.text);
              Navigator.pop(context, count);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (count == null || count <= 0) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final serials = await AdminDashboardService.generateSerialNumbers(count);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated $count QR codes successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating QR codes: $e')),
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

  Future<void> _assignQRCode(Map<String, dynamic> user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get available QR codes
      final availableQRCodes = await AdminDashboardService.getAvailableQRCodes();
      
      setState(() {
        _isLoading = false;
      });
      
      if (availableQRCodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR codes available for assignment')),
        );
        return;
      }

      final qrCode = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign QR Code'),
          content: DropdownButtonFormField<Map<String, dynamic>>(
            decoration: const InputDecoration(
              labelText: 'Select QR Code',
            ),
            items: availableQRCodes.map((qr) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: qr,
                child: Text(qr['serial']),
              );
            }).toList(),
            onChanged: (value) => Navigator.pop(context, value),
          ),
        ),
      );

      if (qrCode == null) return;

      setState(() {
        _isLoading = true;
      });

      await AdminDashboardService.assignQRCodeToUser(
        user['id'],
        qrCode['serial'],
      );
      
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code assigned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning QR code: $e')),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'QR Codes'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: _generateQRCodes,
              tooltip: 'Generate QR Codes',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildUsersTab(),
                  _buildQRCodesTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search users',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _searchUsers();
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(user['name'] ?? 'No name'),
                  subtitle: Text(user['email'] ?? 'No email'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user['qr_code'] != null)
                        IconButton(
                          icon: const Icon(Icons.qr_code),
                          onPressed: () {
                            // Show QR code details
                          },
                          tooltip: 'View QR Code',
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.add_box),
                          onPressed: () => _assignQRCode(user),
                          tooltip: 'Assign QR Code',
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          // Edit user
                        },
                        tooltip: 'Edit User',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQRCodesTab() {
    return ListView.builder(
      itemCount: _qrCodes.length,
      itemBuilder: (context, index) {
        final qrCode = _qrCodes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(qrCode['serial'] ?? 'No serial'),
            subtitle: Text(qrCode['assigned_to_name'] ?? 'Not assigned'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  onPressed: () {
                    // Show QR code
                  },
                  tooltip: 'View QR Code',
                ),
                if (qrCode['assigned_to_name'] == null)
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: () {
                      // Assign to user
                    },
                    tooltip: 'Assign to User',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

