import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart' as auth_service;
import '../services/users_auth_service.dart' as users_auth_service;
import 'conversation_detail_screen.dart'; // Import the missing screen

class RecentConversationsScreen extends StatefulWidget {
  final ApiService apiService;
  final String? childId;
  final auth_service.AuthService? authService;
  final users_auth_service.AuthService? usersAuthService;
  
  const RecentConversationsScreen({
    super.key,
    required this.apiService,
    this.childId,
    this.authService,
    this.usersAuthService,
  });
  
  @override
  State<RecentConversationsScreen> createState() => _RecentConversationsScreenState();
}

class _RecentConversationsScreenState extends State<RecentConversationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Conversation> _conversations = [];
  bool _isAdmin = false;
  
  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadConversations();
  }
  
  Future<void> _checkAdminStatus() async {
    if (widget.authService != null) {
      final isAdmin = await widget.authService!.isCurrentUserAdmin();
      if (mounted) {
        setState(() => _isAdmin = isAdmin);
      }
    }
  }
  
  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get auth token if available
      String? token;
      if (widget.usersAuthService != null) {
        token = await widget.usersAuthService!.getToken();
      }
      
      // Use mock data for testing
      final conversationsData = await widget.apiService.getMockRecentConversations();
      
      // In production, use this:
      // final conversationsData = await widget.apiService.getRecentConversations(
      //   childId: widget.childId,
      //   token: token,
      // );
      
      final conversations = conversationsData
          .map((data) => Conversation.fromJson(data))
          .toList();
      
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Conversations'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin View',
              onPressed: () {
                // Show admin options
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Admin Options'),
                    content: const Text('Additional admin features for conversation management will be available here.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
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
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading conversations',
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
              onPressed: _loadConversations,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConversationsList() {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF9CA3AF),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Conversations with Immy Bear will appear here',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _buildConversationCard(conversation);
        },
      ),
    );
  }
  
  Widget _buildConversationCard(Conversation conversation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationDetailScreen(
                apiService: widget.apiService,
                conversationId: conversation.id,
                authService: widget.authService,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conversation.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          conversation.formattedDate,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${conversation.messageCount} messages',
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (conversation.summary != null) ...[
                const SizedBox(height: 12),
                Text(
                  conversation.summary!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: conversation.topics.map((topic) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      topic,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      onPressed: () {
                        // Show delete confirmation
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
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  // Delete conversation logic would go here
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Conversation deleted')),
                                  );
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Flag'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                      ),
                      onPressed: () {
                        // Show flag options
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Conversation flagged for review')),
                                  );
                                },
                                child: const Text('Flag'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
