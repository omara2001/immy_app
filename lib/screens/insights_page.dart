import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InsightsPage extends StatefulWidget {
  final ApiService apiService;

  const InsightsPage({
    super.key,
    required this.apiService,
  });

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _insightsData;
  String? _errorMessage;
  final String _collectionName = 'emma_conversations'; // Default collection name

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // In a real app, this would fetch data from the API
      // For demo purposes, we'll use mock data
      // final insights = await widget.apiService.getInsights(_collectionName);
      
      // Mock data for demonstration
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      _insightsData = {
        'new_words': 12,
        'topics': 5,
        'questions': 23,
        'summary': 'Emma is showing interest in animals and space. Her vocabulary is growing with new words like "orbit" and "galaxy".',
        'conversations': [
          {
            'title': 'Learning About Space',
            'time': 'Today, 2:30 PM',
            'content': 'Emma asked about planets and stars. Immy explained the solar system in a simple way...',
            'icon': Icons.psychology,
            'color': const Color(0xFF4F46E5), // indigo-600
            'bgColor': const Color(0xFFE0E7FF), // indigo-100
          },
          {
            'title': 'Storytime: The Brave Knight',
            'time': 'Yesterday, 7:15 PM',
            'content': 'Immy told a bedtime story about a brave knight who saved a dragon...',
            'icon': Icons.book,
            'color': const Color(0xFFD97706), // amber-600
            'bgColor': const Color(0xFFFEF3C7), // amber-100
          },
          {
            'title': 'Singing the Alphabet',
            'time': 'Yesterday, 4:00 PM',
            'content': 'Emma practiced the alphabet song with Immy, focusing on the letters Q, R, and S...',
            'icon': Icons.volume_up,
            'color': const Color(0xFF16A34A), // green-600
            'bgColor': const Color(0xFFDCFCE7), // green-100
          },
        ],
      };
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load insights: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _buildInsightsView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2), // red-100
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)), // red-300
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFEF4444), // red-500
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB91C1C), // red-700
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInsights,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6), // purple-600
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)), // gray-300
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)), // gray-400
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)), // gray-300
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_list,
                size: 18,
                color: Color(0xFF6B7280), // gray-500
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insights Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInsightCard(
                      'New Words', 
                      _insightsData!['new_words'].toString(), 
                      const Color(0xFFEFF6FF), 
                      const Color(0xFF1D4ED8)
                    ),
                    const SizedBox(width: 8),
                    _buildInsightCard(
                      'Topics', 
                      _insightsData!['topics'].toString(), 
                      const Color(0xFFDCFCE7), 
                      const Color(0xFF16A34A)
                    ),
                    const SizedBox(width: 8),
                    _buildInsightCard(
                      'Questions', 
                      _insightsData!['questions'].toString(), 
                      const Color(0xFFEDE9FE), 
                      const Color(0xFF7C3AED)
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _insightsData!['summary'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563), // gray-600
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'RECENT CONVERSATIONS',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color(0xFF6B7280), // gray-500
          ),
        ),
        const SizedBox(height: 12),
        ..._insightsData!['conversations'].map<Widget>((conversation) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildConversationCard(
              context,
              conversation['title'],
              conversation['time'],
              conversation['content'],
              conversation['bgColor'],
              conversation['color'],
              conversation['icon'],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInsightCard(String title, String count, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280), // gray-500
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(
    BuildContext context,
    String title,
    String time,
    String content,
    Color bgColor,
    Color iconColor,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: bgColor,
                  child: Icon(
                    icon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280), // gray-500
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563), // gray-600
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}