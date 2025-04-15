class Conversation {
  final String id;
  final String title;
  final DateTime timestamp;
  final int messageCount;
  final List<String> topics;
  final String? summary;
  
  Conversation({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messageCount,
    required this.topics,
    this.summary,
  });
  
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      timestamp: DateTime.parse(json['timestamp']),
      messageCount: json['message_count'],
      topics: List<String>.from(json['topics'] ?? []),
      summary: json['summary'],
    );
  }
  
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
