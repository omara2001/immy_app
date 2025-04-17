import 'package:flutter/material.dart';
import 'package:immy_app/services/serial_service.dart';
import '../services/admin_dashboard_service.dart';
import '../services/auth_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AuthService authService;
  final SerialService serialService;

  const AdminDashboardScreen({
    Key? key,
    required this.authService, 
    required this.serialService,
  }) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  // Check if user is admin before loading data
  Future<void> _checkAdmin() async {
    final isAdmin = await widget.authService.isCurrentUserAdmin();
    if (!isAdmin) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Access denied: Admin privileges required';
          _isLoading = false;
        });
        // Navigate back to login after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/admin/login');
          }
        });
      }
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Double-check admin status for security
      final isAdmin = await widget.authService.isCurrentUserAdmin();
      if (!isAdmin) {
        setState(() {
          _errorMessage = 'Access denied: Admin privileges required';
          _isLoading = false;
        });
        return;
      }

      final users = await AdminDashboardService.getRegisteredUsers();
      
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchUsers(String email) async {
    if (email.isEmpty) {
      _loadData();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final users = await AdminDashboardService.searchUsersByEmail(email);
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to search users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _assignQRCode(int userId) async {
    final TextEditingController qrCodeController = TextEditingController();
    
    final qrCode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign QR Code'),
        content: TextField(
          controller: qrCodeController,
          decoration: const InputDecoration(
            labelText: 'Enter QR Code',
            hintText: 'e.g., IMMY-2025-123456',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, qrCodeController.text),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (qrCode != null && qrCode.isNotEmpty) {
      try {
        await AdminDashboardService.assignQRCodeToUser(userId, qrCode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code assigned successfully')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to assign QR Code: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']?.toString() ?? '');
    final emailController = TextEditingController(text: user['email']?.toString() ?? '');
    
    // Default to false since we may not have this field
    bool isAdmin = false;
    
    // Try to get admin status from auth service if possible
    try {
      final userDetails = await widget.authService.getUserById(user['id']);
      if (!mounted) return;
      if (userDetails != null && userDetails['is_admin'] != null) {
        isAdmin = userDetails['is_admin'] == true;
      }
    } catch (e) {
      debugPrint('Could not fetch admin status: $e');
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SwitchListTile(
                title: const Text('Admin User'),
                value: isAdmin,
                onChanged: (value) {
                  setState(() {
                    isAdmin = value;
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
              onPressed: () {
                if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                  Navigator.pop(context, {
                    'name': nameController.text,
                    'email': emailController.text,
                    'is_admin': isAdmin,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await AdminDashboardService.updateUserProfile(
          user['id'],
          result['name']!,
          result['email']!,
        );
        await AdminDashboardService.setUserAdmin(
          user['id'],
          result['is_admin']!,
        );
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Email',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchUsers(_searchController.text),
                ),
              ),
              onSubmitted: _searchUsers,
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: ListTile(
                      title: Text(user['name']?.toString() ?? 'N/A'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: ${user['email']}'),
                          if (user['qr_code'] != null)
                            Text(
                              'QR Code: ${user['qr_code']} (${user['qr_status']})',
                              style: TextStyle(
                                color: user['qr_status'] == 'active'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user['qr_code'] == null)
                            TextButton(
                              onPressed: () => _assignQRCode(user['id']),
                              child: const Text('Assign QR'),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditUserDialog(user),
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
    );
  }
}
