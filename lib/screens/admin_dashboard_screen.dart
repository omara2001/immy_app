import 'package:flutter/material.dart';
import '../services/serial_service.dart';
import '../services/auth_service.dart';
import '../models/serial_number.dart';
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
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<SerialNumber> _serials = [];
  List<UserProfile> _users = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check if user is admin
      final isAdmin = await widget.authService.isCurrentUserAdmin();
      if (!isAdmin) {
        setState(() {
          _errorMessage = 'Access denied: Admin privileges required';
          _isLoading = false;
        });
        return;
      }

      // Load serials and users
      final serials = await widget.serialService.getSerialList();
      final users = await widget.serialService.getAllUsers();

      setState(() {
        _serials = serials;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateNewSerials() async {
    try {
      final count = await _showGenerateDialog();
      if (count != null && count > 0) {
        await widget.serialService.generateSerials(count);
        _loadData(); // Reload data
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<int?> _showGenerateDialog() async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Serial Numbers'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Number of serials to generate',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              Navigator.of(context).pop(count);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
        ),
        body: Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.authService.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Serial Numbers'),
                Tab(text: 'Users'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Serial Numbers Tab
                  _buildSerialsTab(),
                  // Users Tab
                  _buildUsersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateNewSerials,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSerialsTab() {
    return ListView.builder(
      itemCount: _serials.length,
      itemBuilder: (context, index) {
        final serial = _serials[index];
        final assignedUser = serial.assignedToUserId != null
            ? _users.firstWhere(
                (user) => user.id == serial.assignedToUserId,
                orElse: () => UserProfile(
                  id: 'unknown',
                  name: 'Unknown User',
                  email: 'unknown',
                ),
              )
            : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(serial.serial),
            subtitle: assignedUser != null
                ? Text('Assigned to: ${assignedUser.name}')
                : const Text('Unassigned'),
            trailing: IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () {
                // Show QR code
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(serial.serial),
                    content: Image.asset(
                      serial.qrCodePath,
                      width: 200,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.qr_code,
                          size: 200,
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(user.name),
            subtitle: Text(user.email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.isAdmin ? 'Admin' : 'User'),
                Switch(
                  value: user.isAdmin,
                  onChanged: (value) async {
                    try {
                      await widget.authService.setUserAsAdmin(user.id, value);
                      _loadData(); // Reload data
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
