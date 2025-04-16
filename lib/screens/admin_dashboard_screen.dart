import 'package:flutter/material.dart';
import '../services/serial_service.dart';
import '../services/auth_service.dart';
import '../models/serial_number.dart';
import '../models/user_profile.dart';
import '../services/users_auth_service.dart' as user_auth;

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
  UserProfile? _currentUser;
  final _userAuthService = user_auth.AuthService(); // Add user auth service

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
      _errorMessage = '';
    });

    try {
      // First check if user is admin in users_auth_service
      final isUserAdmin = await _userAuthService.isCurrentUserAdmin();
      print("Admin dashboard - user auth service isAdmin check: $isUserAdmin");
      
      if (isUserAdmin) {
        // If user is admin in users_auth_service, sync with auth_service
        await _syncAdminUser();
      }
      
      // Now check if user is admin in auth_service
      final isAdmin = await widget.authService.isCurrentUserAdmin();
      print("Admin dashboard - admin auth service isAdmin check: $isAdmin");
      
      if (!isAdmin && !isUserAdmin) {
        setState(() {
          _errorMessage = 'Access denied: Admin privileges required';
          _isLoading = false;
        });
        return;
      }

      // Load serials and users
      try {
        _serials = await widget.serialService.getSerialList();
        _users = await widget.serialService.getAllUsers();
        
        // If no data, initialize with sample data
        if (_serials.isEmpty || _users.isEmpty) {
          await widget.serialService.initWithSampleData();
          _serials = await widget.serialService.getSerialList();
          _users = await widget.serialService.getAllUsers();
        }
        
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        print("Error loading data: $e");
        setState(() {
          _errorMessage = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Sync admin user between auth services
  Future<void> _syncAdminUser() async {
    try {
      // Get user from users_auth_service
      final user = await _userAuthService.getCurrentUser();
      if (user != null && user.isAdmin) {
        print("Syncing admin user from users_auth_service to auth_service");
        // Create or update admin user in auth_service
        await widget.authService.createAdminUser(
          user.name, 
          user.email, 
          'admin' // Use default admin password
        );
      }
    } catch (e) {
      print("Error syncing admin user: $e");
    }
  }

  // Rest of the code remains the same...
  // (Keep all the existing methods and UI code)

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

  Future<void> _assignSerialToUser(SerialNumber serial) async {
    try {
      final userId = await _showUserSelectionDialog();
      if (userId != null) {
        final user = _users.firstWhere((u) => u.id == userId);
        await widget.serialService.assignSerialToUser(user, serial);
        _loadData(); // Reload data
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<String?> _showUserSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select User'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                onTap: () => Navigator.of(context).pop(user.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewUser() async {
    try {
      final result = await _showCreateUserDialog();
      if (result != null) {
        final (name, email, isAdmin) = result;
        await widget.serialService.createUserProfile(name, email, isAdmin: isAdmin);
        _loadData(); // Reload data
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<(String, String, bool)?> _showCreateUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    bool isAdmin = false;

    return showDialog<(String, String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New User'),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                  Navigator.of(context).pop((
                    nameController.text,
                    emailController.text,
                    isAdmin,
                  ));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Back to Login'),
              ),
            ],
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

    // Return the existing UI for the admin dashboard
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
              await _userAuthService.logout(); // Logout from both services
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      drawer: _buildAdminDrawer(),
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
        onPressed: () {
          DefaultTabController.of(context).index == 0
              ? _generateNewSerials()
              : _createNewUser();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAdminDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_currentUser?.name ?? 'Admin User'),
            accountEmail: Text(_currentUser?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _currentUser?.name.isNotEmpty == true
                    ? _currentUser!.name[0].toUpperCase()
                    : 'A',
                style: const TextStyle(fontSize: 24),
              ),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Serial Management'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/serial-management');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('User Management'),
            onTap: () {
              Navigator.pop(context);
              DefaultTabController.of(context).animateTo(1); // Switch to Users tab
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Admin Settings'),
            onTap: () {
              Navigator.pop(context);
              _showAdminSettingsDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Return to Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await widget.authService.logout();
              await _userAuthService.logout(); // Logout from both services
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAdminSettingsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configure admin-specific settings here.'),
            SizedBox(height: 16),
            Text('This area can be expanded with additional admin features as needed.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSerialsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serial Numbers: ${_serials.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Assigned: ${_serials.where((s) => s.assignedToUserId != null).length}',
                        ),
                        Text(
                          'Unassigned: ${_serials.where((s) => s.assignedToUserId == null).length}',
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Generate'),
                    onPressed: _generateNewSerials,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        tooltip: 'Assign to User',
                        onPressed: serial.assignedToUserId == null
                            ? () => _assignSerialToUser(serial)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code),
                        tooltip: 'View QR Code',
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

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.people_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Users: ${_users.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Admins: ${_users.where((u) => u.isAdmin).length}',
                        ),
                        Text(
                          'Regular Users: ${_users.where((u) => !u.isAdmin).length}',
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add User'),
                    onPressed: _createNewUser,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              // Find serials assigned to this user
              final userSerials = _serials
                  .where((serial) => serial.assignedToUserId == user.id)
                  .toList();
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  leading: CircleAvatar(
                    backgroundColor: user.isAdmin 
                        ? Colors.purple.shade100 
                        : Colors.blue.shade100,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: user.isAdmin 
                            ? Colors.purple.shade800 
                            : Colors.blue.shade800,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.isAdmin ? 'Admin' : 'User',
                        style: TextStyle(
                          color: user.isAdmin 
                              ? Colors.purple 
                              : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: user.isAdmin,
                        activeColor: Colors.purple,
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigned Serial Numbers: ${userSerials.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (userSerials.isEmpty)
                            const Text('No serial numbers assigned to this user.')
                          else
                            ...userSerials.map((serial) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.qr_code, size: 16),
                                  const SizedBox(width: 8),
                                  Text(serial.serial),
                                ],
                              ),
                            )),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit User'),
                                onPressed: () => _showEditUserDialog(user),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.password),
                                label: const Text('Reset Password'),
                                onPressed: () => _showResetPasswordDialog(user),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEditUserDialog(UserProfile user) async {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    bool isAdmin = user.isAdmin;

    final result = await showDialog<(String, String, bool)?>(
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                  Navigator.of(context).pop((
                    nameController.text,
                    emailController.text,
                    isAdmin,
                  ));
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
        final (name, email, isAdmin) = result;
        // Update user profile
        // This would require adding an updateUserProfile method to your SerialService
        // For now, we'll just update the admin status
        await widget.authService.setUserAsAdmin(user.id, isAdmin);
        _loadData(); // Reload data
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showResetPasswordDialog(UserProfile user) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    String errorMessage = '';

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reset password for ${user.name}'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: obscurePassword,
              ),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: obscureConfirmPassword,
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  setState(() {
                    errorMessage = 'Password cannot be empty';
                  });
                  return;
                }
                if (passwordController.text != confirmPasswordController.text) {
                  setState(() {
                    errorMessage = 'Passwords do not match';
                  });
                  return;
                }
                Navigator.of(context).pop(passwordController.text);
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        // Reset user password
        await widget.authService.changePassword(user.id, result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
