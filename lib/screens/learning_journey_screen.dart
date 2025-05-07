import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningJourneyScreen extends StatefulWidget {
  const LearningJourneyScreen({super.key});

  @override
  State<LearningJourneyScreen> createState() => _LearningJourneyScreenState();
}

class _LearningJourneyScreenState extends State<LearningJourneyScreen> {
  bool _isLoading = true;
  String _learningLevel = 'Age 5-7 (Kindergarten)';
  String _childInterests = 'Space, Animals, Music';

  final List<String> _availableLevels = [
    'Age 3-4 (Preschool)',
    'Age 5-7 (Kindergarten)',
    'Age 8-10 (Elementary)',
    'Age 11-13 (Middle School)'
  ];

  final List<String> _availableInterests = [
    'Space',
    'Animals',
    'Music',
    'Science',
    'Math',
    'Reading',
    'Art',
    'Nature'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _learningLevel = prefs.getString('learningLevel') ?? 'Age 5-7 (Kindergarten)';
      _childInterests = prefs.getString('childInterests') ?? 'Space, Animals, Music';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('learningLevel', _learningLevel);
    await prefs.setString('childInterests', _childInterests);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Learning preferences saved')),
      );
    }
  }

  void _showLevelSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Learning Level'),
        content: SizedBox(
          width: double.maxFinite,
          height: 250,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableLevels.length,
            itemBuilder: (context, index) {
              final level = _availableLevels[index];
              return ListTile(
                title: Text(level),
                trailing: level == _learningLevel
                    ? const Icon(Icons.check, color: Color(0xFF8B5CF6))
                    : null,
                onTap: () {
                  setState(() {
                    _learningLevel = level;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showInterestsSelectionDialog() {
    // Parse current interests into a list
    final currentInterests = _childInterests.split(', ');
    final selectedInterests = List<String>.from(currentInterests);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Child\'s Interests'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableInterests.length,
                itemBuilder: (context, index) {
                  final interest = _availableInterests[index];
                  final isSelected = selectedInterests.contains(interest);

                  return CheckboxListTile(
                    title: Text(interest),
                    value: isSelected,
                    activeColor: const Color(0xFF8B5CF6),
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedInterests.add(interest);
                        } else {
                          selectedInterests.remove(interest);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _childInterests = selectedInterests.join(', ');
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Journey'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save preferences',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Learning Preferences',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Customize Immy\'s educational approach',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Learning Level Card
                  _buildSettingCard(
                    'Learning Level',
                    _learningLevel,
                    Icons.school,
                    onTap: _showLevelSelectionDialog,
                  ),
                  const SizedBox(height: 16),

                  // Interests Card
                  _buildSettingCard(
                    'Child\'s Interests',
                    _childInterests,
                    Icons.favorite,
                    onTap: _showInterestsSelectionDialog,
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingCard(
    String title,
    String value,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFEDE9FE),
                    child: Icon(
                      icon,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to change',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B5CF6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.edit,
                    size: 12,
                    color: Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
