import 'package:flutter/material.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                        _buildInsightCard('New Words', '12', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)), // blue-50, blue-700
                        const SizedBox(width: 8),
                        _buildInsightCard('Topics', '5', const Color(0xFFDCFCE7), const Color(0xFF16A34A)), // green-50, green-700
                        const SizedBox(width: 8),
                        _buildInsightCard('Questions', '23', const Color(0xFFEDE9FE), const Color(0xFF7C3AED)), // purple-50, purple-700
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Emma is showing interest in animals and space. Her vocabulary is growing with new words like "orbit" and "galaxy".',
                      style: TextStyle(
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
            _buildConversationCard(
              context,
              'Learning About Space',
              'Today, 2:30 PM',
              'Emma asked about planets and stars. Immy explained the solar system in a simple way...',
              const Color(0xFFE0E7FF), // indigo-100
              const Color(0xFF4F46E5), // indigo-600
              Icons.psychology,
            ),
            const SizedBox(height: 12),
            _buildConversationCard(
              context,
              'Storytime: The Brave Knight',
              'Yesterday, 7:15 PM',
              'Immy told a bedtime story about a brave knight who saved a dragon...',
              const Color(0xFFFEF3C7), // amber-100
              const Color(0xFFD97706), // amber-600
              Icons.book,
            ),
            const SizedBox(height: 12),
            _buildConversationCard(
              context,
              'Singing the Alphabet',
              'Yesterday, 4:00 PM',
              'Emma practiced the alphabet song with Immy, focusing on the letters Q, R, and S...',
              const Color(0xFFDCFCE7), // green-100
              const Color(0xFF16A34A), // green-600
              Icons.volume_up,
            ),
          ],
        ),
      ),
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