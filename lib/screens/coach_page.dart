import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CoachPage extends StatefulWidget {
  final ApiService apiService;

  const CoachPage({
    super.key,
    required this.apiService,
  });

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _coachData;
  String? _errorMessage;
  final String _collectionName = 'emma_conversations'; // Default collection name

  @override
  void initState() {
    super.initState();
    _loadCoachData();
  }

  Future<void> _loadCoachData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // In a real app, this would fetch data from the API
      // For demo purposes, we'll use mock data
      // final enhancements = await widget.apiService.getEnhancements(_collectionName);
      
      // Mock data for demonstration
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      _coachData = {
        'engagement': 87,
        'new_skills': 5,
        'activities': [
          {
            'title': 'Solar System Craft',
            'description': 'Create a model solar system using household items to build on Emma\'s space interest.',
            'bgColor': const Color(0xFFEDE9FE), // purple-50
            'iconColor': const Color(0xFF8B5CF6), // purple-600
            'icon': Icons.rocket,
          },
          {
            'title': 'Number Scavenger Hunt',
            'description': 'Find and count objects around the house to practice numbers up to 20.',
            'bgColor': const Color(0xFFDDEEFD), // blue-50
            'iconColor': const Color(0xFF2563EB), // blue-600
            'icon': Icons.book,
          },
        ],
        'milestones': [
          {
            'title': 'Advanced Number Recognition',
            'description': 'Successfully counted to 20 without help',
            'bgColor': const Color(0xFFDCFCE7), // green-100
            'iconColor': const Color(0xFF16A34A), // green-600
            'icon': Icons.star,
          },
          {
            'title': 'Scientific Curiosity',
            'description': 'Growing interest in space and planets',
            'bgColor': const Color(0xFFDDEEFD), // blue-100
            'iconColor': const Color(0xFF2563EB), // blue-600
            'icon': Icons.psychology,
          },
        ],
        'tips': [
          {
            'title': 'Nurture Scientific Thinking',
            'content': 'When Emma asks about space, encourage her to make predictions. Ask "What do you think happens when...?" to develop critical thinking skills.',
          },
          {
            'title': 'Math in Daily Life',
            'content': 'Include counting in everyday activities, like setting the table or sorting laundry, to reinforce number skills naturally.',
          },
        ],
      };
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load coach data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? _buildErrorView()
            : _buildCoachView();
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
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
              onPressed: _loadCoachData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6), // purple-600
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF8B5CF6), // purple-600
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Learning Coach',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Emma\'s personalized guidance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard('${_coachData!['engagement']}%', 'Engagement'),
                    const SizedBox(width: 16),
                    _buildStatCard(_coachData!['new_skills'].toString(), 'New Skills'),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _coachData!['activities'][0]['title'] + ', ' + _coachData!['activities'][0]['description'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Milestones Section
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Milestones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.trending_up,
                      color: Color(0xFF16A34A), // green-600
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._coachData!['milestones'].map<Widget>((milestone) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildMilestoneItem(
                      milestone['title'],
                      milestone['description'],
                      milestone['bgColor'],
                      milestone['iconColor'],
                      milestone['icon'],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 24),
                
                // Recommended Activities Section
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recommended Activities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.bolt,
                      color: Color(0xFF8B5CF6), // purple-600
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._coachData!['activities'].map<Widget>((activity) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildActivityCard(
                      activity['title'],
                      activity['description'],
                      activity['bgColor'],
                      activity['iconColor'],
                      activity['icon'],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 24),
                
                // Expert Tips Section
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expert Tips',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFFD97706), // amber-600
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._coachData!['tips'].map<Widget>((tip) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildTipCard(
                      tip['title'],
                      tip['content'],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE), // purple-50
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFDDD6FE), // purple-100
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Color(0xFF8B5CF6), // purple-600
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'These insights are based on Emma\'s recent interactions with Immy, focusing on space exploration and number learning.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5B21B6), // purple-800
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: label == 'Engagement' 
              ? const Color(0xFFE0E7FF) // indigo-100
              : const Color(0xFFFCE7F3), // pink-100
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: label == 'Engagement' 
                    ? const Color(0xFF4F46E5) // indigo-600
                    : const Color(0xFFDB2777), // pink-600
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: label == 'Engagement' 
                    ? const Color(0xFF4F46E5).withOpacity(0.8) // indigo-600
                    : const Color(0xFFDB2777).withOpacity(0.8), // pink-600
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneItem(
    String title,
    String description,
    Color bgColor,
    Color iconColor,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280), // gray-500
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(
    String title,
    String description,
    Color bgColor,
    Color iconColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563), // gray-600
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'View Instructions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward,
                size: 12,
                color: iconColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Color(0xFFFBBF24), // amber-400
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563), // gray-600
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
