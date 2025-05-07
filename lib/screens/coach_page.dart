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
        title: const Text('Coach'),
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
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCoachData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return _buildErrorView();
    if (_coachData == null || _coachData!["recommendations"] == null) {
      return const Center(child: Text("No recommendations available"));
    }

    final recommendations = _coachData!["recommendations"] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recommendations.entries.map((entry) {
          final key = entry.key;
          final value = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTitle(key),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (value is List)
                  ...value.map<Widget>((item) => _buildItemCard(item)).toList()
                else if (value is Map)
                  _buildKeyValueCard(value)
                else
                  Text(value.toString()),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatTitle(String raw) {
    return raw.replaceAll('_', ' ').replaceFirstMapped(
        RegExp(r'^[a-z]'), (match) => match.group(0)!.toUpperCase());
  }

  Widget _buildItemCard(dynamic item) {
    // Check if item is a Map, otherwise convert it to a Map with a default key
    final Map<String, dynamic> itemMap;
    if (item is Map) {
      itemMap = Map<String, dynamic>.from(item);
    } else {
      // Handle case where item is a String or other non-Map type
      itemMap = {'value': item.toString()};
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: itemMap.entries.map<Widget>((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "${_formatTitle(entry.key)}: ${entry.value}",
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: mapData.entries.map<Widget>((entry) {
            final value = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "${_formatTitle(entry.key)}: ${value is List ? value.join(", ") : value.toString()}",
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCoachData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
