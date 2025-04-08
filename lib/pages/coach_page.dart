import 'package:flutter/material.dart';

class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('87%', 'Engagement'),
                    _buildStatCard('5', 'New Skills'),
                    _buildStatCard('12', 'Activities'),
                  ],
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
                _buildMilestoneItem(
                  'Advanced Number Recognition',
                  'Successfully counted to 20 without help',
                  const Color(0xFFDCFCE7), // green-100
                  const Color(0xFF16A34A), // green-600
                  Icons.star,
                ),
                const SizedBox(height: 12),
                _buildMilestoneItem(
                  'Scientific Curiosity',
                  'Growing interest in space and planets',
                  const Color(0xFFDDEEFD), // blue-100
                  const Color(0xFF2563EB), // blue-600
                  Icons.psychology,
                ),
                
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
                _buildActivityCard(
                  'Solar System Craft',
                  'Create a model solar system using household items to build on Emma\'s space interest.',
                  const Color(0xFFEDE9FE), // purple-50
                  const Color(0xFF8B5CF6), // purple-600
                  Icons.rocket,
                ),
                const SizedBox(height: 12),
                _buildActivityCard(
                  'Number Scavenger Hunt',
                  'Find and count objects around the house to practice numbers up to 20.',
                  const Color(0xFFDDEEFD), // blue-50
                  const Color(0xFF2563EB), // blue-600
                  Icons.book,
                ),
                
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
                _buildTipCard(
                  'Nurture Scientific Thinking',
                  'When Emma asks about space, encourage her to make predictions. Ask "What do you think happens when...?" to develop critical thinking skills.',
                ),
                const SizedBox(height: 12),
                _buildTipCard(
                  'Math in Daily Life',
                  'Include counting in everyday activities, like setting the table or sorting laundry, to reinforce number skills naturally.',
                ),
                
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
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