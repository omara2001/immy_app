import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Process files (موجود بس مش محتاجه هنا حسب كلامك)
  Future<Map<String, dynamic>> processFiles(List<File> files, {String? collectionName}) async {
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

    if (collectionName != null) {
      request.fields['collection_name'] = collectionName;
    }

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
  Future<Map<String, dynamic>> getCollectionInfo(String collectionName) async {
    final uri = Uri.parse('$baseUrl/collection-info/$collectionName');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get collection info: ${response.statusCode}');
    }
  }

  // Get enhancement suggestions
  Future<Map<String, dynamic>> getEnhancements(String collectionName) async {
    final uri = Uri.parse('$baseUrl/enhancements/$collectionName');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get enhancements: ${response.statusCode}');
    }
  }

  // Get summary of collection
  Future<Map<String, dynamic>> getSummary(String collectionName) async {
    final uri = Uri.parse('$baseUrl/summarize/$collectionName');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get summary: ${response.statusCode}');
    }
  }

  // Get insights from collection
  Future<Map<String, dynamic>> getInsights(String collectionName, {int? clusters, bool? detailed}) async {
    var uri = Uri.parse('$baseUrl/insights/$collectionName');
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

  // Get recent conversations - تعديلها تعتمد على collection-info
  Future<List<Map<String, dynamic>>> getRecentConversations({String? childId, String? token}) async {
    final collectionName = childId ?? 'default_collection'; // أو تحط اسم الكوليكشن المناسب

    final info = await getCollectionInfo(collectionName);
    final files = info['files'] as List<dynamic>? ?? [];

    return files.map((file) => {
      'id': file,
      'title': file,
      'timestamp': DateTime.now().toIso8601String(), // مفيش تايمستامب بالظبط فا Placeholder
      'message_count': info['total_documents'] ?? 0,
      'topics': [], // مفيش توبكس واضحة هنا
      'summary': '',
    }).toList();
  }

  // Get real conversations - تعديلها تعتمد على collection-info و summary
  Future<List<Map<String, dynamic>>> getRealConversations(String? token) async {
    try {
      final collectionName = 'default_collection'; // أو بحسب الطفل

      final info = await getCollectionInfo(collectionName);

      final files = info['files'] as List<dynamic>? ?? [];

      return files.map((file) => {
        'id': file,
        'title': file,
        'timestamp': DateTime.now().toIso8601String(),
        'message_count': info['total_documents'] ?? 0,
        'topics': [],
        'summary': '',
      }).toList();
    } catch (e) {
      print('Error getting real conversations: $e');
      return [];
    }
  }

  // Get conversation details - اعتمد على summarize
  Future<Map<String, dynamic>> getConversationDetails(String conversationId, {String? token}) async {
    final summary = await getSummary(conversationId); // اعتبر أن كل CollectionName = ConversationId
    return summary;
  }

  // No more mock methods needed
}
