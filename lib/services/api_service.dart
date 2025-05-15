import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'https://f3m8ekbvk8.execute-api.eu-west-2.amazonaws.com'});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Process files (موجود بس مش محتاجه هنا حسب كلامك)
  Future<Map<String, dynamic>> processFiles(List<File> files) async {
    final uri = Uri.parse('$baseUrl/process-files');
    final request = http.MultipartRequest('POST', uri);

    for (var file in files) {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final contentType = extension == 'pdf'
          ? MediaType('application', 'pdf')
          : MediaType('text', 'plain');

      request.files.add(await http.MultipartFile.fromPath(
        'files',
        file.path,
        contentType: contentType,
      ));
    }

    request.fields['collection_name'] = 'transcription';

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to process files: ${response.statusCode}, $responseBody');
    }
  }

  // Get processing status (مش هنحتاجه فعليًا لو مش بترفع ملفات)
  Future<Map<String, dynamic>> getProcessStatus(String batchId) async {
    final uri = Uri.parse('$baseUrl/process-status/$batchId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get process status: ${response.statusCode}');
    }
  }

  // Get collection information
  Future<Map<String, dynamic>> getCollectionInfo() async {
    final uri = Uri.parse('$baseUrl/collection-info/transcription');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get collection info: ${response.statusCode}');
    }
  }

  // Get enhancement suggestions
  Future<Map<String, dynamic>> getEnhancements() async {
    final uri = Uri.parse('$baseUrl/enhancements/transcription');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get enhancements: ${response.statusCode}');
    }
  }

  // Get summary of collection
  Future<Map<String, dynamic>> getSummary() async {
    final uri = Uri.parse('$baseUrl/summarize/transcription');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get summary: ${response.statusCode}');
    }
  }

  // Get insights from collection
  Future<Map<String, dynamic>> getInsights({int? clusters, bool? detailed}) async {
    var uri = Uri.parse('$baseUrl/insights/transcription');
    final queryParams = <String, String>{};

    if (clusters != null) {
      queryParams['clusters'] = clusters.toString();
    }
    if (detailed != null) {
      queryParams['detailed'] = detailed.toString();
    }

    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get insights: ${response.statusCode}');
    }
  }

  // Get recent conversations
  Future<List<Map<String, dynamic>>> getRecentConversations() async {
    final info = await getCollectionInfo();
    final files = info['files'] as List<dynamic>? ?? [];

    return files.map((file) => {
      'id': file,
      'title': file,
      'timestamp': DateTime.now().toIso8601String(),
      'message_count': info['total_documents'] ?? 0,
      'topics': [],
      'summary': '',
    }).toList();
  }

  // Get real conversations
  Future<List<Map<String, dynamic>>> getRealConversations(String? token) async {
    try {
      final info = await getCollectionInfo();
      final files = info['files'] as List<dynamic>? ?? [];
      
      // Use a Set to track unique file names and prevent duplicates
      final Set<String> uniqueFiles = <String>{};
      final List<Map<String, dynamic>> conversations = [];
      
      for (final file in files) {
        final fileName = file.toString();
        // Only add the file if it's not already in our set
        if (uniqueFiles.add(fileName)) {
          conversations.add({
            'id': fileName,
            'title': fileName,
            'timestamp': DateTime.now().toIso8601String(),
            'message_count': info['total_documents'] ?? 0,
            'topics': [],
            'summary': '',
            // Add the first few lines of content as a preview
            'preview': await _getFilePreview(fileName),
          });
        }
      }
      
      return conversations;
    } catch (e) {
      print('Error getting real conversations: $e');
      return [];
    }
  }
  
  // Helper method to get a preview of the file content
  Future<String> _getFilePreview(String fileName) async {
    try {
      // In a real implementation, you would fetch the first few lines of the file
      // For now, we'll return a mock preview based on the file name
      if (fileName.contains('transcription')) {
        return 'Once upon a time in a cozy little burrow lived a tiny Mouse named Pip...';
      }
      return 'Preview not available';
    } catch (e) {
      return 'Preview not available';
    }
  }

  // Get conversation details
  Future<Map<String, dynamic>> getConversationDetails(String conversationId, {String? token}) async {
    try {
      final summary = await getSummary();
      
      // Add the conversation ID to the response
      summary['id'] = conversationId;
      summary['title'] = conversationId;
      
      // Add timestamps if they don't exist
      if (!summary.containsKey('start_time')) {
        summary['start_time'] = DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String();
      }
      if (!summary.containsKey('end_time')) {
        summary['end_time'] = DateTime.now().toIso8601String();
      }
      
      // Add sample messages if they don't exist
      if (!summary.containsKey('messages') || (summary['messages'] as List).isEmpty) {
        summary['messages'] = [
          {
            'sender': 'Immy',
            'content': 'Hello! How can I help you today?',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
          },
          {
            'sender': 'User',
            'content': 'I have a question about my Immy Bear.',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 23)).toIso8601String(),
          },
          {
            'sender': 'Immy',
            'content': 'Of course! What would you like to know about your Immy Bear?',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 22)).toIso8601String(),
          },
        ];
      }
      
      return summary;
    } catch (e) {
      print('Error getting conversation details: $e');
      // Return a minimal valid response with sample messages
      return {
        'id': conversationId,
        'title': conversationId,
        'start_time': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'messages': [
          {
            'sender': 'Immy',
            'content': 'Hello! How can I help you today?',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
          },
          {
            'sender': 'User',
            'content': 'I have a question about my Immy Bear.',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 23)).toIso8601String(),
          },
        ],
        'summary': 'Failed to load conversation summary.',
      };
    }
  }

  // Get summary for a specific conversation
  Future<Map<String, dynamic>> getConversationSummary(String conversationId) async {
    try {
      final uri = Uri.parse('$baseUrl/conversations/$conversationId/summary');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get conversation summary: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting conversation summary: $e');
      // For demo purposes, return a mock summary if API fails
      return {
        'summary': 'This is a summary of conversation $conversationId. The conversation covered topics like learning, play, and imagination.',
        'topics': ['learning', 'play', 'imagination'],
        'sentiment': 'positive',
      };
    }
  }
}
