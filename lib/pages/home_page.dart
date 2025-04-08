import 'package:flutter/material.dart';
import '../widgets/subscription_banner.dart';
import 'insights_page.dart';
import 'coach_page.dart';
import 'payments_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const InsightsPage(),
    const CoachPage(),
    const PaymentsPage(),
    const SettingsPage(),
  ];

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
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
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
                  Icons.group_add,
                  'Add Another Immy',
                  'Link a new Immy bear',
                  const Color(0xFFEDE9FE), // purple-100
                  const Color(0xFF8B5CF6), // purple-600
                ),
              ],
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
    Color iconColor,
  ) {
    return Card(
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
    );
  }
}

