import 'package:flutter/material.dart';

class CoachDetailPage extends StatelessWidget {
  final Map<String, dynamic> coachData;
  final String date;
  
  const CoachDetailPage({
    Key? key, 
    required this.coachData, 
    required this.date
  }) : super(key: key);

  String _formatTitle(String text) {
    return text.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Widget _buildKeyValueCard(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries.map<Widget>((entry) {
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

  Widget _buildItemCard(dynamic item) {
    final Map<String, dynamic> itemMap;
    if (item is Map) {
      itemMap = Map<String, dynamic>.from(item);
    } else {
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

  @override
  Widget build(BuildContext context) {
    if (coachData["recommendations"] == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Coach - $date')),
        body: const Center(child: Text("No recommendations available")),
      );
    }

    final recommendations = coachData["recommendations"] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text('Coach - $date')),
      body: SingleChildScrollView(
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
                    _buildKeyValueCard(Map<String, dynamic>.from(value))
                  else
                    Text(value.toString()),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}