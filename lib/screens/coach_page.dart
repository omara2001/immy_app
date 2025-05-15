import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import 'coach_history_page.dart';

class CoachPage extends StatefulWidget {
  final ApiService apiService;
  
  const CoachPage({Key? key, required this.apiService}) : super(key: key);

  @override
  _CoachPageState createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _coachData;
  String? _errorMessage;
  final String _collectionName = 'transcription';
  final HistoryService _historyService = HistoryService();

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
      final data = await widget.apiService.getEnhancements();
      
      // Save to history
      await _historyService.saveCoachHistory(data);
      
      setState(() => _coachData = data);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load coach data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoachHistoryPage(historyService: _historyService),
                ),
              );
            },
            tooltip: 'View History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCoachData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            SizedBox(height: 16),
            Text("Loading coach insights...", 
              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500))
          ],
        )
      );
    }
    
    if (_errorMessage != null) return _buildErrorView();
    
    if (_coachData == null || _coachData!["recommendations"] == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("No recommendations available", 
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _loadCoachData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    final recommendations = _coachData!["recommendations"] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF3E8FF), Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            ...recommendations.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildRecommendationSection(key, value),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lightbulb, color: Color(0xFF4F46E5), size: 32),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Personalized Insights",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Based on your child's recent conversations",
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(String key, dynamic value) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getSectionIcon(key),
                const SizedBox(width: 12),
                Text(
                  _formatTitle(key),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (value is List)
              ...value.map<Widget>((item) => _buildItemCard(item)).toList()
            else if (value is Map)
              _buildKeyValueCard(value)
            else
              Text(value.toString(), style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _getSectionIcon(String key) {
    IconData iconData;
    Color iconColor;
    
    // Assign icons based on section name
    if (key.contains('vocabulary') || key.contains('word')) {
      iconData = Icons.menu_book;
      iconColor = const Color(0xFF4F46E5);
    } else if (key.contains('topic') || key.contains('theme')) {
      iconData = Icons.category;
      iconColor = const Color(0xFF16A34A);
    } else if (key.contains('progress') || key.contains('improvement')) {
      iconData = Icons.trending_up;
      iconColor = const Color(0xFFEA580C);
    } else if (key.contains('suggestion') || key.contains('recommend')) {
      iconData = Icons.lightbulb;
      iconColor = const Color(0xFFCA8A04);
    } else {
      iconData = Icons.insights;
      iconColor = const Color(0xFF8B5CF6);
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor),
    );
  }

  Widget _buildItemCard(dynamic item) {
    final Map<String, dynamic> itemMap;
    if (item is Map) {
      itemMap = Map<String, dynamic>.from(item);
    } else {
      itemMap = {'value': item.toString()};
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: itemMap.entries.map<Widget>((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_formatTitle(entry.key)}: ",
                    style: const TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151)
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "${entry.value}",
                      style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKeyValueCard(Map mapData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: mapData.entries.map<Widget>((entry) {
            final value = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_formatTitle(entry.key)}: ",
                    style: const TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151)
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value is List ? value.join(", ") : value.toString(),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? 'An error occurred',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCoachData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTitle(String text) {
    if (text.isEmpty) return '';
    
    // Replace underscores with spaces
    String formatted = text.replaceAll('_', ' ');
    
    // Capitalize each word
    formatted = formatted.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return formatted;
  }
}
