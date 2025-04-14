import 'package:flutter/material.dart';
import '../widgets/subscription_banner.dart';
import '../services/serial_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'insights_page.dart';
import 'coach_page.dart';
import 'payments_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final SerialService serialService;
  final ApiService apiService;
  final AuthService? authService; // Make optional for backward compatibility

  const HomePage({
    super.key, 
    required this.serialService,
    required this.apiService,
    this.authService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize the pages with the services
    _pages = [
      const HomeContent(),
      InsightsPage(apiService: widget.apiService),
      CoachPage(apiService: widget.apiService),
      const PaymentsPage(),
      SettingsPage(serialService: widget.serialService),
    ];
    
    // Initialize sample data for testing
    _initSampleData();
    
    // Check if user is admin
    _checkAdminStatus();
  }
  
  Future<void> _initSampleData() async {
    try {
      // This will now throw an exception if the user is not an admin
      await widget.serialService.initWithSampleData();
    } catch (e) {
      // It's okay if this fails due to admin restrictions
      print('Note: Sample data initialization restricted: $e');
    }
  }
  
  Future<void> _checkAdminStatus() async {
    if (widget.authService != null) {
      final isAdmin = await widget.authService!.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B5CF6), // purple-600
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                'IA',
                style: TextStyle(
                  color: Color(0xFF8B5CF6), // purple-600
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Immy App',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/serial-management');
            },
          ),
          // Add admin icon if user is admin
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              tooltip: 'Admin Dashboard',
              onPressed: () {
                Navigator.pushNamed(context, '/admin/dashboard');
              },
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              _showAppDrawer(context);
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF8B5CF6), // purple-600
        unselectedItemColor: const Color(0xFF6B7280), // gray-500
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Coach',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
  
  void _showAppDrawer(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }
  
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF8B5CF6), // purple-600
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Text(
                    'IA',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6), // purple-600
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Immy App',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  _isAdmin ? 'Admin Account' : 'User Account',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _selectedIndex = 0;
              });
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
            leading: const Icon(Icons.search),
            title: const Text('Serial Lookup'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/serial-lookup');
            },
          ),
          // Admin section
          if (widget.authService != null) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Administration',
                style: TextStyle(
                  color: Color(0xFF6B7280), // gray-500
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/dashboard');
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Admin Login'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/login');
                },
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to help page
            },
          ),
          if (_isAdmin && widget.authService != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await widget.authService!.logout();
                if (mounted) {
                  setState(() {
                    _isAdmin = false;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged out successfully')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SubscriptionBanner(isActive: true),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFDDEEFD), // blue-100
                          child: Text(
                            'IB',
                            style: TextStyle(
                              color: Color(0xFF1E40AF), // blue-800
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Immy Bear',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Last active: 25 minutes ago',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280), // gray-500
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), // blue-50
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '"Today, Emma learned about dinosaurs and practiced counting to 20."',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E40AF), // blue-800
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildQuickActionCard(
                  context,
                  Icons.history,
                  'Recent Conversations',
                  'View what Emma has been learning',
                  const Color(0xFFE0E7FF), // indigo-100
                  const Color(0xFF4F46E5), // indigo-600
                  onTap: () {
                    Navigator.of(context).pushNamed('/serial-lookup');
                  },
                ),
                _buildQuickActionCard(
                  context,
                  Icons.trending_up,
                  'Learning Journey',
                  'Adjust learning preferences',
                  const Color(0xFFDCFCE7), // green-100
                  const Color(0xFF16A34A), // green-600
                ),
                _buildQuickActionCard(
                  context,
                  Icons.book,
                  'Story Time',
                  'Browse magical stories',
                  const Color(0xFFFEF3C7), // amber-100
                  const Color(0xFFD97706), // amber-600
                ),
                _buildQuickActionCard(
                  context,
                  Icons.qr_code,
                  'Manage Devices',
                  'Link a new Immy bear',
                  const Color(0xFFEDE9FE), // purple-100
                  const Color(0xFF8B5CF6), // purple-600
                  onTap: () {
                    Navigator.of(context).pushNamed('/serial-management');
                  },
                ),
              ],
            ),
            // Add Admin Card if needed
            Builder(
              builder: (context) {
                // Access the HomePage state to check admin status
                final homePageState = context.findAncestorStateOfType<_HomePageState>();
                if (homePageState != null && homePageState._isAdmin) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Administration',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: const Color(0xFFFEF2F2), // red-50
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pushNamed('/admin/dashboard');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFFFEE2E2), // red-100
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    size: 20,
                                    color: const Color(0xFFDC2626), // red-600
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Admin Dashboard',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Manage serials and users',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280), // gray-500
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color bgColor,
    Color iconColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: bgColor,
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280), // gray-500
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
