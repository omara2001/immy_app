import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import 'insights_history_page.dart';

class InsightsPage extends StatefulWidget {
  final ApiService apiService;
  
  const InsightsPage({Key? key, required this.apiService}) : super(key: key);

  @override
  _InsightsPageState createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _insightsData;
  String? _errorMessage;
  final String _collectionName = 'transcription';
  final HistoryService _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final insights = await widget.apiService.getInsights();
      
      // Save to history
      await _historyService.saveInsightsHistory(insights);
      
      setState(() {
        _insightsData = insights;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load insights: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InsightsHistoryPage(historyService: _historyService),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _buildInsightsView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
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
            onPressed: _loadInsights,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsView() {
    if (_insightsData == null) {
      return const Center(child: Text('No insights available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildSummarySection(),
        const SizedBox(height: 24),
        _buildConversationsSection(),
      ],
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
                _buildInsightCard('New Words', _insightsData?['cluster_analysis']?['total_points']?.toString() ?? '0', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                _buildInsightCard('Clusters', _insightsData?['cluster_analysis']?['number_of_clusters']?.toString() ?? '0', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _insightsData?['executive_summary'] ?? '',
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String count, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsSection() {
    final conversations = _insightsData?['cluster_analysis']?['clusters'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RECENT CONVERSATIONS', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        ...conversations.entries.map<Widget>((entry) {
          final cluster = entry.value;
          final samples = cluster['representative_samples'] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: samples.map<Widget>((sample) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sample['file_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(sample['content'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ],
    );
  }
}
