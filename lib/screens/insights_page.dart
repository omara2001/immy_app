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
        title: const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
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
            tooltip: 'Refresh',
            onPressed: _loadInsights,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF3E8FF), Colors.white],
        ),
      ),
      child: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  SizedBox(height: 16),
                  Text("Loading insights...", 
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500))
                ],
              )
            )
          : _errorMessage != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildInsightsView(),
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
                onPressed: _loadInsights,
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

  Widget _buildInsightsView() {
    if (_insightsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("No insights available", 
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildSummarySection(),
        const SizedBox(height: 24),
        _buildConversationsSection(),
      ],
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
              child: const Icon(Icons.insights, color: Color(0xFF4F46E5), size: 32),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Language Insights",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Analysis of recent conversations",
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

  Widget _buildSummarySection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.summarize, color: Color(0xFF8B5CF6)),
                SizedBox(width: 8),
                Text('Insights Summary', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildInsightCard(
                  'New Words', 
                  _insightsData?['cluster_analysis']?['total_points']?.toString() ?? '0', 
                  const Color(0xFFEFF6FF), 
                  const Color(0xFF1D4ED8),
                  Icons.text_fields
                ),
                const SizedBox(width: 12),
                _buildInsightCard(
                  'Clusters', 
                  _insightsData?['cluster_analysis']?['number_of_clusters']?.toString() ?? '0', 
                  const Color(0xFFDCFCE7), 
                  const Color(0xFF16A34A),
                  Icons.bubble_chart
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Executive Summary', 
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF4B5563))),
                  const SizedBox(height: 8),
                  Text(
                    _insightsData?['executive_summary'] ?? 'No summary available',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String count, Color bgColor, Color textColor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8))
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 20, 
                      color: textColor
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsSection() {
    final conversations = _insightsData?['cluster_analysis']?['clusters'] ?? {};
    // Track already displayed file names and content to avoid duplicates
    final Set<String> displayedContents = {};

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forum, color: Color(0xFF8B5CF6)),
                SizedBox(width: 8),
                Text('RECENT CONVERSATIONS', 
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF6B7280))),
              ],
            ),
            const Divider(height: 24),
            ...conversations.entries.map<Widget>((entry) {
              final cluster = entry.value;
              final samples = cluster['representative_samples'] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: samples.map<Widget>((sample) {
                  final fileName = sample['file_name'] ?? '';
                  final content = sample['content'] ?? '';
                  
                  // Create a unique key combining filename and content
                  final uniqueKey = '$fileName:$content';
                  
                  // Skip if this content has already been displayed
                  if (displayedContents.contains(uniqueKey)) {
                    return const SizedBox.shrink();
                  }
                  displayedContents.add(uniqueKey);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
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
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.description, size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 8),
                                Text(
                                  fileName, 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 14,
                                    color: Color(0xFF374151)
                                  )
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Text(
                              content, 
                              style: const TextStyle(
                                fontSize: 14, 
                                color: Color(0xFF4B5563),
                                height: 1.5
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
