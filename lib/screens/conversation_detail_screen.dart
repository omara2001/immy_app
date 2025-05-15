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
  final String? initialSummary;

  const ConversationDetailScreen({
    super.key,
    required this.apiService,
    required this.conversationId,
    this.authService,
    this.usersAuthService,
    this.initialSummary,
  });

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  ConversationDetail? _conversation;
  bool _isAdmin = false; // Add this variable

  @override
  void initState() {
    super.initState();
    
    _checkAdminStatus(); // Call this method to check admin status
    
    if (widget.initialSummary != null) {
      // If we already have a summary, create a basic conversation object
      setState(() {
        _conversation = ConversationDetail(
          id: widget.conversationId,
          title: widget.conversationId,
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          messages: [],
          insights: {
            'topics': ['conversation', 'learning'],
            'sentiment': 'positive',
          },
          summary: widget.initialSummary!,
        );
        _isLoading = false;
      });
    } else {
      _loadConversationDetails();
    }
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

  Widget _buildKeyMoments() {
    final keyMoments = _conversation?.insights?['key_moments'] as List<dynamic>? ?? [];
    if (keyMoments.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Moments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),
          ...keyMoments.map((moment) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.star,
                  size: 16,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    moment.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildConversationStats() {
    final duration = _conversation?.insights?['duration'] as String? ?? '';
    final wordCount = _conversation?.insights?['word_count'] as int? ?? 0;
    final childEngagement = _conversation?.insights?['child_engagement'] as String? ?? '';
    
    if (duration.isEmpty && wordCount == 0 && childEngagement.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conversation Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(Icons.timer, 'Duration', duration),
              const SizedBox(width: 24),
              _buildStatItem(Icons.text_fields, 'Words', wordCount.toString()),
              const SizedBox(width: 24),
              _buildStatItem(Icons.psychology, 'Engagement', childEngagement),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_conversation?.title ?? 'Conversation'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isAdmin)
            _buildAdminMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildConversationHeader(),
                      _buildKeyMoments(),
                      _buildConversationStats(),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Conversation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._conversation!.messages.map((message) {
                              final isImmy = message.sender.toLowerCase() == 'immy';
                              return _buildMessageBubble(message, isImmy);
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _conversation!.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _conversation!.summary.isNotEmpty 
                ? _conversation!.summary 
                : 'No summary available',
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 20),
          _buildInsightsTags(),
        ],
      ),
    );
  }

  Widget _buildInsightsTags() {
    final topics = _conversation?.insights?['topics'] as List<dynamic>? ?? [];
    final sentiment = _conversation?.insights?['sentiment'] as String? ?? '';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conversation Insights',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Topics Discussed',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topics.map<Widget>((topic) {
            return Chip(
              label: Text(
                topic.toString(),
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: const Color(0xFFF3F4F6),
              padding: const EdgeInsets.all(4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Overall Sentiment: ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sentiment.toLowerCase() == 'positive' 
                    ? const Color(0xFFDCFCE7) 
                    : sentiment.toLowerCase() == 'negative'
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    sentiment.toLowerCase() == 'positive' 
                        ? Icons.sentiment_satisfied_alt
                        : sentiment.toLowerCase() == 'negative'
                            ? Icons.sentiment_dissatisfied
                            : Icons.sentiment_neutral,
                    size: 16,
                    color: sentiment.toLowerCase() == 'positive' 
                        ? const Color(0xFF059669) 
                        : sentiment.toLowerCase() == 'negative'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sentiment,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sentiment.toLowerCase() == 'positive' 
                          ? const Color(0xFF059669) 
                          : sentiment.toLowerCase() == 'negative'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
            CircleAvatar(
              backgroundColor: const Color(0xFFEDE9FE),
              radius: 16,
              child: Text(
                message.sender.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Color(0xFF5B21B6), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
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
