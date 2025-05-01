import 'package:flutter/material.dart';
import '../models/conversation_detail.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart' as auth_service;
import '../services/users_auth_service.dart' as users_auth_service;

class ConversationDetailScreen extends StatefulWidget {
  final ApiService apiService;
  final String conversationId;
  final auth_service.AuthService? authService;
  final users_auth_service.AuthService? usersAuthService;

  const ConversationDetailScreen({
    super.key,
    required this.apiService,
    required this.conversationId,
    this.authService,
    this.usersAuthService,
  });

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  ConversationDetail? _conversation;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadConversationDetails();
  }

  Future<void> _checkAdminStatus() async {
    if (widget.authService != null) {
      final isAdmin = await widget.authService!.isCurrentUserAdmin();
      if (mounted) {
        setState(() => _isAdmin = isAdmin);
      }
    }
  }

  Future<void> _loadConversationDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? token;
      if (widget.usersAuthService != null) {
        token = await widget.usersAuthService!.getToken();
      }

      // ✅ نستخدم الداتا الحقيقية من API
      final data = await widget.apiService.getConversationDetails(
        widget.conversationId,
        token: token,
      );

      if (mounted) {
        setState(() {
          _conversation = ConversationDetail.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load conversation details. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_conversation?.title ?? 'Conversation'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            _buildAdminMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildConversationDetail(),
    );
  }

  PopupMenuButton<String> _buildAdminMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'export') {
          _showSnackbar('Exporting conversation...');
        } else if (value == 'delete') {
          _showDeleteDialog();
        } else if (value == 'flag') {
          _showFlagDialog();
        }
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem('Export', Icons.download_outlined, 'export'),
        _buildPopupMenuItem('Flag', Icons.flag_outlined, 'flag'),
        _buildPopupMenuItem('Delete', Icons.delete_outline, 'delete', isDanger: true),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String text, IconData icon, String value, {bool isDanger = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDanger ? const Color(0xFFDC2626) : null),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: isDanger ? const Color(0xFFDC2626) : null),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close the screen
              _showSnackbar('Conversation deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFlagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flag Conversation'),
        content: const Text('Select a reason for flagging this conversation:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackbar('Conversation flagged for review');
            },
            child: const Text('Flag'),
          ),
        ],
      ),
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
              'Error loading conversation',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadConversationDetails,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationDetail() {
    if (_conversation == null) {
      return const Center(child: Text('No conversation data available'));
    }

    return Column(
      children: [
        _buildConversationHeader(),
        Expanded(child: _buildMessageList()),
        if (_conversation!.insights != null) _buildInsightsSection(),
      ],
    );
  }

  Widget _buildConversationHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF9FAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.chat_bubble_outline, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conversation!.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      _conversation!.formattedDate,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.access_time, _conversation!.duration, const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.chat, '${_conversation!.messages.length} messages', const Color(0xFFEDE9FE), const Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: iconColor)),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversation!.messages.length,
      itemBuilder: (context, index) {
        final message = _conversation!.messages[index];
        final isImmy = message.sender.toLowerCase() == 'immy';
        return _buildMessageBubble(message, isImmy);
      },
    );
  }

  Widget _buildMessageBubble(ConversationMessage message, bool isImmy) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isImmy ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isImmy) ...[
            const CircleAvatar(backgroundColor: Color(0xFFDDEEFD), radius: 16, child: Text('IB', style: TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isImmy ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isImmy ? const Color(0xFFEFF6FF) : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: isImmy ? Radius.zero : null,
                      bottomRight: !isImmy ? Radius.zero : null,
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(fontSize: 14, color: isImmy ? const Color(0xFF1E40AF) : const Color(0xFF5B21B6)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.formattedTime,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          if (!isImmy) ...[
            const SizedBox(width: 8),
            const CircleAvatar(backgroundColor: Color(0xFFF3E8FF), radius: 16, child: Text('E', style: TextStyle(color: Color(0xFF7E22CE), fontWeight: FontWeight.bold, fontSize: 12))),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    final insights = _conversation!.insights!;

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF9FAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Conversation Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (insights.containsKey('topics')) _buildTopics(insights['topics']),
          if (insights.containsKey('sentiment')) _buildSentiment(insights['sentiment']),
          if (insights.containsKey('learning_points')) _buildLearningPoints(insights['learning_points']),
        ],
      ),
    );
  }

  Widget _buildTopics(List topics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Topics Discussed', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topics.map<Widget>((topic) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Text(topic, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSentiment(String sentiment) {
    Color color;
    IconData icon;
    switch (sentiment.toLowerCase()) {
      case 'positive':
        color = const Color(0xFF16A34A);
        icon = Icons.sentiment_satisfied;
        break;
      case 'negative':
        color = const Color(0xFFDC2626);
        icon = Icons.sentiment_dissatisfied;
        break;
      case 'neutral':
        color = const Color(0xFF4B5563);
        icon = Icons.sentiment_neutral;
        break;
      default:
        color = const Color(0xFF4B5563);
        icon = Icons.sentiment_neutral;
    }

    return Row(
      children: [
        const Text('Overall Sentiment:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(sentiment, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearningPoints(List points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Learning Points', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        ...points.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(point, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)))),
                ],
              ),
            )),
      ],
    );
  }
}
