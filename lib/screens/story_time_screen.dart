import 'package:flutter/material.dart';

class StoryTimeScreen extends StatefulWidget {
  const StoryTimeScreen({super.key});

  @override
  State<StoryTimeScreen> createState() => _StoryTimeScreenState();
}

class _StoryTimeScreenState extends State<StoryTimeScreen> {
  final List<Map<String, dynamic>> _stories = [
    {
      'id': '1',
      'title': 'The Magical Forest',
      'description': 'Join Emma on a magical adventure through an enchanted forest filled with talking animals and hidden treasures.',
      'category': 'Fantasy',
      'duration': '5 min',
      'image': 'assets/immy_BrainyBear.png',
    },
    {
      'id': '2',
      'title': 'Counting Stars',
      'description': 'Learn to count with Emma as she discovers the wonders of the night sky.',
      'category': 'Educational',
      'duration': '3 min',
      'image': 'assets/immy_BrainyBear.png',
    },
    {
      'id': '3',
      'title': 'Dinosaur Discovery',
      'description': 'Travel back in time with Emma to learn about different dinosaurs and their habitats.',
      'category': 'Educational',
      'duration': '7 min',
      'image': 'assets/immy_BrainyBear.png',
    },
    {
      'id': '4',
      'title': 'Bedtime for Teddy',
      'description': 'A soothing bedtime story about a teddy bear getting ready for sleep.',
      'category': 'Bedtime',
      'duration': '4 min',
      'image': 'assets/immy_BrainyBear.png',
    },
    {
      'id': '5',
      'title': 'Ocean Adventure',
      'description': 'Dive deep into the ocean with Emma to discover amazing sea creatures.',
      'category': 'Adventure',
      'duration': '6 min',
      'image': 'assets/immy_BrainyBear.png',
    },
    {
      'id': '6',
      'title': 'The Friendly Lion',
      'description': 'Meet Leo the Lion who learns the importance of friendship and kindness.',
      'category': 'Animals',
      'duration': '5 min',
      'image': 'assets/immy_BrainyBear.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Time'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Magical Stories',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore wonderful stories for your child',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // Stories List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stories.length,
              itemBuilder: (context, index) {
                final story = _stories[index];
                return _buildStoryCard(story);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(Map<String, dynamic> story) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openStoryDetail(story),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Story image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  story['image'],
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),

              // Story details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            story['category'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          story['duration'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story['description'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStoryDetail(Map<String, dynamic> story) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryDetailScreen(story: story),
      ),
    );
  }
}

class StoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> story;

  const StoryDetailScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(story['title']),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            Image.asset(
              story['image'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

            // Story details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Story metadata
                  Row(
                    children: [
                      _buildInfoChip(story['category'], const Color(0xFFEDE9FE), const Color(0xFF8B5CF6)),
                      const SizedBox(width: 8),
                      _buildInfoChip(story['duration'], const Color(0xFFEDE9FE), const Color(0xFF8B5CF6)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Story description
                  const Text(
                    'Story Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story['description'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Play button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Play the story
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play Story'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
