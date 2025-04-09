import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Base URL for the API
  final String baseUrl;
  
  // Constructor with default base URL
  ApiService({this.baseUrl = 'http://localhost:8000'});
  
  // Headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Process files and store in Qdrant collection
  Future<Map<String, dynamic>> processFiles(List<File> files, {String? collectionName}) async {
    final uri = Uri.parse('$baseUrl/process-files');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Add files to request
    for (var file in files) {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final contentType = extension == 'pdf' 
          ? MediaType('application', 'pdf')
          : MediaType('text', 'plain');
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'files',
          file.path,
          contentType: contentType,
        ),
      );
    }
    
    // Add collection name if provided
    if (collectionName != null) {
      request.fields['collection_name'] = collectionName;
    }
    
    // Send request
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to process files: ${response.statusCode}, $responseBody');
    }
  }
  
  // Get processing status
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
  Future<Map<String, dynamic>> getInsights(
    String collectionName, {
    int? clusters,
    bool? detailed,
  }) async {
    var uri = Uri.parse('$baseUrl/insights/$collectionName');
    
    // Add query parameters if provided
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
}