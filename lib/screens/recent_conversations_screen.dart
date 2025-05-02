import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'conversation_detail_screen.dart';

class RecentConversationsScreen extends StatefulWidget {
  final ApiService apiService;

  const RecentConversationsScreen({
    super.key,
    required this.apiService,
  });

  @override
  State<RecentConversationsScreen> createState() => _RecentConversationsScreenState();
}

class _RecentConversationsScreenState extends State<RecentConversationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _fileNames = [];
  final String _collectionName = 'emma_conversations';

  @override
  void initState() {
    super.initState();
    _loadFileNames();
  }

  Future<void> _loadFileNames() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await widget.apiService.getCollectionInfo(_collectionName);
      final files = info['files'] as List<dynamic>;
      setState(() {
        _fileNames = List<String>.from(files);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load conversations: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openConversation(String fileName) async {
    try {
      final summary = await widget.apiService.getSummary(_collectionName);
      final content = summary['summary'];

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            apiService: widget.apiService,
            conversationId: fileName,
            authService: null,
            usersAuthService: null,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading conversation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Conversations'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildConversationsList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            Text(
              'Error loading conversations',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFileNames,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_fileNames.isEmpty) {
      return const Center(
        child: Text('No conversations found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fileNames.length,
      itemBuilder: (context, index) {
        final fileName = _fileNames[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF4F46E5)),
            title: Text(fileName),
            subtitle: Text('Tap to view summary'),
            onTap: () => _openConversation(fileName),
          ),
        );
      },
    );
  }
}
