import 'package:flutter/material.dart';

class InsightsDetailPage extends StatelessWidget {
  final Map<String, dynamic> insightsData;
  final String date;
  
  const InsightsDetailPage({
    Key? key, 
    required this.insightsData, 
    required this.date
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Insights for $date'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummarySection(),
            const SizedBox(height: 16),
            _buildClusterSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Insights Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInsightCard('New Words', insightsData['cluster_analysis']?['total_points']?.toString() ?? '0', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                _buildInsightCard('Clusters', insightsData['cluster_analysis']?['number_of_clusters']?.toString() ?? '0', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterSection() {
    final clusters = insightsData['cluster_analysis']?['clusters'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Word Clusters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ...clusters.map((cluster) {
              final words = cluster['words'] as List<dynamic>? ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cluster: ${cluster['name'] ?? 'Unnamed'}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: words.map<Widget>((word) {
                        return Chip(
                          label: Text(word.toString()),
                          backgroundColor: const Color(0xFFE5E7EB),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
