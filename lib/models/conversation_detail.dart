class ConversationMessage {
  final String sender;
  final String content;
  final DateTime timestamp;

  ConversationMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      sender: json['sender'] ?? 'Unknown',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class ConversationDetail {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final List<ConversationMessage> messages;
  Map<String, dynamic>? insights; // NOT final anymore, so it can be updated
  final String summary; // Added summary field

  ConversationDetail({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.messages,
    this.insights,
    this.summary = '', // Default empty string
  });

  // Factory to create ConversationDetail from JSON
  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      id: json['id'],
      title: json['title'],
      startTime: DateTime.parse(json['start_time'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['end_time'] ?? DateTime.now().toIso8601String()),
      messages: (json['messages'] as List? ?? [])
          .map((msg) => ConversationMessage.fromJson(msg))
          .toList(),
      insights: json['insights'],
      summary: json['summary'] ?? '',
    );
  }

  // Calculate conversation duration
  String get duration {
    final difference = endTime.difference(startTime);
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;
    return '$minutes min ${seconds}s';
  }

  // Format date nicely
  String get formattedDate {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }
}
