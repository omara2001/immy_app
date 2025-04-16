class ConversationMessage {
  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;
  
  ConversationMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
  });
  
  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'],
      sender: json['sender'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
  
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class ConversationDetail {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final List<ConversationMessage> messages;
  final Map<String, dynamic>? insights;
  
  ConversationDetail({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.messages,
    this.insights,
  });
  
  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      id: json['id'],
      title: json['title'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      messages: (json['messages'] as List)
          .map((msg) => ConversationMessage.fromJson(msg))
          .toList(),
      insights: json['insights'],
    );
  }
  
  String get duration {
    final difference = endTime.difference(startTime);
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;
    
    return '$minutes min ${seconds}s';
  }
  
  String get formattedDate {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }
}
