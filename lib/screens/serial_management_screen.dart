import 'package:flutter/material.dart';
import '../models/serial_number.dart';
import '../models/user_profile.dart';
import '../services/serial_service.dart';
import '../services/backend_api_service.dart';
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

class _SerialManagementScreenState extends State<SerialManagementScreen> with SingleTickerProviderStateMixin {
  List<SerialNumber> _serials = [];
  List<UserProfile> _users = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    // Create tab controller
    _tabController = TabController(length: 2, vsync: this);
    // Explicitly set to first tab
    _tabController.index = 0;
    // Load data
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First initialize the database if needed
      try {
        await BackendApiService.initializeDatabase();
      } catch (e) {
        debugPrint('DB initialization warning (may be already initialized): $e');
      }
      
      // Load serials and users
      _serials = await widget.serialService.getSerialList();
      _users = await widget.serialService.getAllUsers();
      _filteredUsers = List.from(_users);
      
      // If no data, initialize with sample data
      if (_serials.isEmpty || _users.isEmpty) {
        await widget.serialService.initWithSampleData();
        _serials = await widget.serialService.getSerialList();
        _users = await widget.serialService.getAllUsers();
        _filteredUsers = List.from(_users);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = List.from(_users);
      });
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        return user.name.toLowerCase().contains(lowerQuery) || 
               user.email.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _generateSerials() async {
    final TextEditingController countController = TextEditingController(text: '1');
    
    if (!mounted) return;
    
    await showDialog(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final count = int.tryParse(countController.text) ?? 1;
              Navigator.of(context).pop();
              
              if (!mounted) return;
              setState(() {
                _isLoading = true;
              });
              
              try {
                await widget.serialService.generateSerials(count);
                await _loadData();
                
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Generated $count QR codes')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error generating QR codes: $e')),
                );
              } finally {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                });
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignSerial(UserProfile user) async {
    if (!mounted) return;
    final unassignedSerials = _serials.where((s) => s.assignedToUserId == null).toList();
    
    if (unassignedSerials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unassigned QR codes available. Please generate more.')),
      );
      return;
    }
    
    SerialNumber? selectedSerial;
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Assign QR Code to ${user.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<SerialNumber>(
                decoration: const InputDecoration(
                  labelText: 'Select QR Code',
                ),
                value: selectedSerial,
                items: unassignedSerials.map((serial) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedSerial != null
                  ? () {
                      Navigator.of(context).pop(selectedSerial);
                    }
                  : null,
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    ).then((result) async {
      if (result == null || !mounted) return;
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Check if user already has a serial
        final existingSerial = _serials.firstWhere(
          (s) => s.assignedToUserId == user.id,
          orElse: () => SerialNumber(
            id: '',
            serial: '',
            qrCodePath: '',
            status: 'inactive',
          ),
        );
        
        if (existingSerial.id.isNotEmpty) {
          // User already has a serial, confirm replacement
          if (!mounted) return;
          final shouldReplace = await _confirmReplaceSerial(
            user,
            existingSerial,
            result,
          );
          
          if (shouldReplace && mounted) {
            await widget.serialService.replaceSerial(
              user,
              result,
            );
            
            // Show success message with QR preview
            if (mounted) {
              _showQRPreviewBottomSheet(user, result);
            }
          }
        } else {
          // User doesn't have a serial, assign directly
          await widget.serialService.assignSerialToUser(
            user,
            result,
          );
          
          // Show success message with QR preview
          if (mounted) {
            _showQRPreviewBottomSheet(user, result);
          }
        }
        
        // Reload data
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning QR code: $e')),
        );
      } finally {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<bool> _confirmReplaceSerial(
    UserProfile user,
    SerialNumber oldSerial,
    SerialNumber newSerial,
  ) async {
    if (!mounted) return false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace QR Code?'),
        content: Text(
          '${user.name} already has QR code ${oldSerial.serial}. '
          'Do you want to replace it with ${newSerial.serial}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  // Show QR code in a bottom sheet instead of a dialog
  void _showQRPreviewBottomSheet(UserProfile user, SerialNumber serial) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('QR code ${serial.serial} assigned to ${user.name}'),
        action: SnackBarAction(
          label: 'View QR',
          onPressed: () {
            if (!mounted) return;
            
            showModalBottomSheet(
              context: context,
              builder: (context) => Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QR Code for ${user.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: serial.serial,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      serial.serial,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Text('No users found. Try adding users or changing the search query.'),
      );
    }
    
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        
        // Find if user has a serial assigned
        final assignedSerial = _serials.firstWhere(
          (serial) => serial.assignedToUserId == user.id,
          orElse: () => SerialNumber(id: '', serial: '', qrCodePath: '', status: 'inactive'),
        );
        
        final hasSerial = assignedSerial.id.isNotEmpty;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(user.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${user.email}'),
                if (hasSerial)
                  Text(
                    'QR Code: ${assignedSerial.serial}',
                    style: const TextStyle(color: Colors.green),
                  )
                else
                  const Text(
                    'No QR code assigned',
                    style: TextStyle(color: Colors.orange),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSerial)
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View QR Code',
                    onPressed: () {
                      // Show bottom sheet instead of dialog
                      _showQRPreviewBottomSheet(user, assignedSerial);
                    },
                  ),
                IconButton(
                  icon: Icon(
                    hasSerial ? Icons.sync_alt : Icons.qr_code,
                    color: Theme.of(context).primaryColor,
                  ),
                  tooltip: hasSerial ? 'Replace QR Code' : 'Assign QR Code',
                  onPressed: () => _assignSerial(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSerialList() {
    if (_serials.isEmpty) {
      return const Center(
        child: Text('No QR codes generated yet. Use the + button to generate QR codes.'),
      );
    }
    
    return ListView.builder(
      itemCount: _serials.length,
      itemBuilder: (context, index) {
        final serial = _serials[index];
        final isAssigned = serial.assignedToUserId != null;
        
        // Find assigned user name if assigned
        String assignedTo = 'Not assigned';
        if (isAssigned) {
          final user = _users.firstWhere(
            (u) => u.id == serial.assignedToUserId,
            orElse: () => UserProfile(id: '', name: 'Unknown', email: ''),
          );
          assignedTo = 'Assigned to: ${user.name}';
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(serial.serial),
            subtitle: Text(
              assignedTo,
              style: TextStyle(
                color: isAssigned ? Colors.green : Colors.orange,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'View QR Code',
              onPressed: () {
                // Show bottom sheet instead of dialog
                if (isAssigned) {
                  final user = _users.firstWhere(
                    (u) => u.id == serial.assignedToUserId,
                    orElse: () => UserProfile(id: '', name: 'Unknown', email: ''),
                  );
                  _showQRPreviewBottomSheet(user, serial);
                } else {
                  // For unassigned serials, still use bottom sheet
                  _showUnassignedQRPreview(serial);
                }
              },
            ),
          ),
        );
      },
    );
  }
  
  // Show unassigned QR code preview
  void _showUnassignedQRPreview(SerialNumber serial) {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'QR Code (Unassigned)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: serial.serial,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              serial.serial,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Code Management'),
          backgroundColor: const Color(0xFF8B5CF6), // purple-600
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Code Management'),
          backgroundColor: const Color(0xFF8B5CF6), // purple-600
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_error!),
              ),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Management'),
        backgroundColor: const Color(0xFF8B5CF6), // purple-600
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'QR Codes', icon: Icon(Icons.qr_code)),
          ],
          labelColor: Colors.white,
          indicatorColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: _tabController.index == 0 ? 'Search Users' : 'Search QR Codes',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterUsers,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Disable swiping
              children: [
                _buildUserList(),
                _buildSerialList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateSerials,
        backgroundColor: const Color(0xFF8B5CF6), // purple-600
        child: const Icon(Icons.add),
      ),
    );
  }
}
