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
  final String _collectionName = 'emma_conversations';

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
      final data = await widget.apiService.getEnhancements(_collectionName);
      setState(() => _coachData = data);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load coach data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildItemCard(Map item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: item.entries.map<Widget>((entry) {
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
