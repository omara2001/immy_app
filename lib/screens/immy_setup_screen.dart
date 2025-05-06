import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ImmySetupScreen extends StatefulWidget {
  const ImmySetupScreen({super.key});

  @override
  State<ImmySetupScreen> createState() => _ImmySetupScreenState();
}

class _ImmySetupScreenState extends State<ImmySetupScreen> {
  // Current step index
  int _currentStep = 0;
  
  // Form keys for validation
  final _parentFormKey = GlobalKey<FormState>();
  final _childFormKey = GlobalKey<FormState>();
  
  // Parent information
  final TextEditingController _parent1NameController = TextEditingController();
  final TextEditingController _parent2NameController = TextEditingController();
  
  // Child information
  List<Map<String, dynamic>> _children = [
    {'name': TextEditingController(), 'age': TextEditingController()}
  ];
  
  // Focus selection
  String _selectedFocus = '';
  
  // Progress indicator values
  double _step1Progress = 0.33;
  double _step2Progress = 0.66;
  double _step3Progress = 1.0;
  
  bool _isLoading = false;

  @override
  void dispose() {
    _parent1NameController.dispose();
    _parent2NameController.dispose();
    for (var child in _children) {
      child['name'].dispose();
      child['age'].dispose();
    }
    super.dispose();
  }

  // Add another child
  void _addChild() {
    setState(() {
      _children.add({
        'name': TextEditingController(),
        'age': TextEditingController()
      });
    });
  }

  // Remove a child
  void _removeChild(int index) {
    if (_children.length > 1) {
      setState(() {
        final controller1 = _children[index]['name'];
        final controller2 = _children[index]['age'];
        _children.removeAt(index);
        controller1.dispose();
        controller2.dispose();
      });
    }
  }

  // Move to next step
  void _nextStep() {
    if (_currentStep == 0) {
      if (_parentFormKey.currentState!.validate()) {
        setState(() {
          _currentStep = 1;
        });
      }
    } else if (_currentStep == 1) {
      if (_childFormKey.currentState!.validate()) {
        setState(() {
          _currentStep = 2;
        });
      }
    }
  }

  // Move to previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  // Complete setup
  Future<void> _completeSetup() async {
    if (_selectedFocus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a focus area for Immy')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Save all data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Save parent information
      await prefs.setString('parent1Name', _parent1NameController.text);
      await prefs.setString('parent2Name', _parent2NameController.text);
      
      // Save children information
      List<Map<String, String>> childrenData = [];
      for (var child in _children) {
        childrenData.add({
          'name': child['name'].text,
          'age': child['age'].text,
        });
      }
      await prefs.setString('children', jsonEncode(childrenData));
      
      // Save focus area
      await prefs.setString('immyFocus', _selectedFocus);
      
      // Send data to server
      await _sendDataToServer();
      
      // Navigate back to settings or to home
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setup completed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving setup data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Send data to server
  Future<void> _sendDataToServer() async {
    // Create a map of all the setup data
    List<Map<String, String>> childrenData = [];
    for (var child in _children) {
      childrenData.add({
        'name': child['name'].text,
        'age': child['age'].text,
      });
    }
    
    final Map<String, dynamic> setupData = {
      'parent1Name': _parent1NameController.text,
      'parent2Name': _parent2NameController.text,
      'children': childrenData,
      'immyFocus': _selectedFocus,
    };
    
    // Replace with your actual API endpoint
    const String apiUrl = 'https://your-api-endpoint.com/immy/setup-data';
    
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        // Add authentication headers if needed
      },
      body: jsonEncode(setupData),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to sync data: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Immy App'),
        backgroundColor: const Color(0xFF8B5CF6), // Purple color from screenshots
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Purple header
          Container(
            color: const Color(0xFF8B5CF6),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 16,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Set Up Your Immy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Let\'s personalize your experience',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _currentStep == 0 ? _step1Progress : 
                               _currentStep == 1 ? _step2Progress : _step3Progress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content based on current step
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildCurrentStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildParentInformationStep();
      case 1:
        return _buildChildInformationStep();
      case 2:
        return _buildFocusSelectionStep();
      default:
        return Container();
    }
  }

  Widget _buildParentInformationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parent Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _parentFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parent 1 Name',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _parent1NameController,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Parent 1 name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Parent 2 Name',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _parent2NameController,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                // Parent 2 is optional
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
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
      ],
    );
  }

  Widget _buildChildInformationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Child Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _childFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._buildChildrenForms(),
              const SizedBox(height: 16),
              InkWell(
                onTap: _addChild,
                child: Row(
                  children: [
                    Icon(Icons.add, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Add another child',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildrenForms() {
    List<Widget> forms = [];
    
    for (int i = 0; i < _children.length; i++) {
      forms.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Child ${i + 1} Name',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (_children.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeChild(i),
                    color: Colors.grey,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _children[i]['name'],
              decoration: InputDecoration(
                hintText: 'Enter name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter child\'s name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Age',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _children[i]['age'],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter age',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter child\'s age';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid age';
                }
                return null;
              },
            ),
            if (i < _children.length - 1) const SizedBox(height: 24),
            if (i < _children.length - 1) const Divider(),
            if (i < _children.length - 1) const SizedBox(height: 16),
          ],
        ),
      );
    }
    
    return forms;
  }

  Widget _buildFocusSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What should Immy focus on?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select the primary focus for your child\'s Immy experience',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        _buildFocusOption(
          title: 'Education',
          description: 'Focus on learning and skill development',
          icon: Icons.school,
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFE0E7FF),
          value: 'education',
        ),
        const SizedBox(height: 16),
        _buildFocusOption(
          title: 'Entertainment',
          description: 'Focus on fun activities and storytelling',
          icon: Icons.emoji_emotions,
          iconColor: const Color(0xFF3B82F6),
          bgColor: const Color(0xFFDBEAFE),
          value: 'entertainment',
        ),
        const SizedBox(height: 16),
        _buildFocusOption(
          title: 'Emotional Support',
          description: 'Focus on emotional well-being and development',
          icon: Icons.favorite,
          iconColor: const Color(0xFFEC4899),
          bgColor: const Color(0xFFFCE7F3),
          value: 'emotional_support',
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _completeSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Complete Setup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFocusOption({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String value,
  }) {
    final isSelected = _selectedFocus == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFocus = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? bgColor.withOpacity(0.3) : Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: bgColor,
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF8B5CF6),
              ),
          ],
        ),
      ),
    );
  }
}