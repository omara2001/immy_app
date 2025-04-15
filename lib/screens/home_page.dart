import 'package:flutter/material.dart';
import 'package:immy_app/models/user.dart';
import '../widgets/subscription_banner.dart';
import '../services/serial_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart' as auth_service;
import '../services/users_auth_service.dart' as users_auth_service;
import 'insights_page.dart';
import 'coach_page.dart';
import 'payments_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final SerialService serialService;
  final ApiService apiService;
  final auth_service.AuthService? authService;
  final users_auth_service.AuthService? usersAuthService; // Use aliased type

  const HomePage({
    super.key, 
    required this.serialService,
    required this.apiService,
    this.authService,
    this.usersAuthService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  bool _isAdmin = false;
  bool _isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    
    _pages = [
      const HomeContent(),
      InsightsPage(apiService: widget.apiService),
      CoachPage(apiService: widget.apiService),
      const PaymentsPage(),
      SettingsPage(serialService: widget.serialService),
    ];
    
    _initSampleData();
    _checkAdminStatus();
    _loadUserData();
  }

   Future<void> _loadUserData() async {
    if (widget.authService == null) return;
    
    setState(() => _isLoading = true);
    try {
      final user = await widget.authService!.getCurrentUser();
      if (mounted && user != null) {
        setState(() {
          _userName = user.name; // Ensure user object has 'name' property
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userName = 'Error loading name';
        });
      }
    }
  }

  Future<void> _initSampleData() async {
    try {
      await widget.serialService.initWithSampleData();
    } catch (e) {
      print('Note: Sample data initialization restricted: $e');
    }
  }

  Future<void> _checkAdminStatus() async {
    if (widget.authService != null) {
      final isAdmin = await widget.authService!.isCurrentUserAdmin();
      if (mounted) {
        setState(() => _isAdmin = isAdmin);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await widget.authService?.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B5CF6),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                'IA',
                style: TextStyle(
                  color: Color(0xFF8B5CF6),
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
            onPressed: () => Navigator.pushNamed(context, '/serial-management'),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              tooltip: 'Admin Dashboard',
              onPressed: () => Navigator.pushNamed(context, '/admin/dashboard'),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'settings') _selectedIndex = 4;
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    Text(_isLoading ? 'Loading...' : 'Hi, $_userName'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: const Color(0xFF6B7280),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Coach'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF8B5CF6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Text(
                    'IA',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isLoading ? 'Loading...' : _userName,
                  style: const TextStyle(
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
            onTap: () => _updateIndex(0),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Serial Management'),
            onTap: () => Navigator.pushNamed(context, '/serial-management'),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Serial Lookup'),
            onTap: () => Navigator.pushNamed(context, '/serial-lookup'),
          ),
          if (widget.authService != null) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Administration',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _isAdmin
              ? ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Admin Dashboard'),
                  onTap: () => Navigator.pushNamed(context, '/admin/dashboard'),
                )
              : ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Admin Login'),
                  onTap: () => Navigator.pushNamed(context, '/admin/login'),
                ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  void _updateIndex(int index) {
    Navigator.pop(context);
    setState(() => _selectedIndex = index);
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
                          backgroundColor: Color(0xFFDDEEFD),
                          child: Text(
                            'IB',
                            style: TextStyle(
                              color: Color(0xFF1E40AF),
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
                                  color: Color(0xFF6B7280),
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '"Today, Emma learned about dinosaurs and practiced counting to 20."',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E40AF),
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
                  const Color(0xFFE0E7FF),
                  const Color(0xFF4F46E5),
                  onTap: () => Navigator.pushNamed(context, '/serial-lookup'),
                ),
                _buildQuickActionCard(
                  context,
                  Icons.trending_up,
                  'Learning Journey',
                  'Adjust learning preferences',
                  const Color(0xFFDCFCE7),
                  const Color(0xFF16A34A),
                ),
                _buildQuickActionCard(
                  context,
                  Icons.book,
                  'Story Time',
                  'Browse magical stories',
                  const Color(0xFFFEF3C7),
                  const Color(0xFFD97706),
                ),
                _buildQuickActionCard(
                  context,
                  Icons.qr_code,
                  'Manage Devices',
                  'Link a new Immy bear',
                  const Color(0xFFEDE9FE),
                  const Color(0xFF8B5CF6),
                  onTap: () => Navigator.pushNamed(context, '/serial-management'),
                ),
              ],
            ),
            Builder(
              builder: (context) {
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
                        color: const Color(0xFFFEF2F2),
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/admin/dashboard'),
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(0xFFFEE2E2),
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    size: 20,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
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
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16),
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
                child: Icon(icon, size: 20, color: iconColor),
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
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}