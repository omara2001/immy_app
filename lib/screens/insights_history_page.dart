import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/history_service.dart';
import 'insights_detail_page.dart';

class InsightsHistoryPage extends StatefulWidget {
  final HistoryService historyService;
  
  const InsightsHistoryPage({Key? key, required this.historyService}) : super(key: key);

  @override
  _InsightsHistoryPageState createState() => _InsightsHistoryPageState();
}

class _InsightsHistoryPageState extends State<InsightsHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyItems = [];
  
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final history = await widget.historyService.getInsightsHistory();
      setState(() => _historyItems = history);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load history: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat('MMM d, yyyy - h:mm a').format(date);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyItems.isEmpty
              ? const Center(child: Text('No history available'))
              : ListView.builder(
                  itemCount: _historyItems.length,
                  itemBuilder: (context, index) {
                    final item = _historyItems[index];
                    final date = _formatDate(item['date']);
                    
                    return ListTile(
                      title: Text('Insights Data - $date'),
                      leading: const Icon(Icons.insights),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InsightsDetailPage(
                              insightsData: item['data'],
                              date: date,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}