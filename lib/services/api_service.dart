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
  
  // Get recent conversations
  Future<List<Map<String, dynamic>>> getRecentConversations({String? childId, String? token}) async {
    var uri = Uri.parse('$baseUrl/recent-conversations');
    
    // Add child ID as query parameter if provided
    if (childId != null) {
      uri = uri.replace(queryParameters: {'child_id': childId});
    }
    
    // Add authorization header if token is provided
    final headers = Map<String, String>.from(_headers);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == true && data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to get recent conversations: ${response.statusCode}');
    }
  }
  
  // Get conversation details
  Future<Map<String, dynamic>> getConversationDetails(String conversationId, {String? token}) async {
    final uri = Uri.parse('$baseUrl/conversation-details/$conversationId');
    
    // Add authorization header if token is provided
    final headers = Map<String, String>.from(_headers);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == true) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to get conversation details');
      }
    } else {
      throw Exception('Failed to get conversation details: ${response.statusCode}');
    }
  }
  
  // For testing: Get mock recent conversations
  Future<List<Map<String, dynamic>>> getMockRecentConversations() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    return [
      {
        'id': 'conv1',
        'title': 'Learning about Dinosaurs',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'message_count': 12,
        'topics': ['Dinosaurs', 'Paleontology', 'Science'],
        'summary': 'Emma asked about different types of dinosaurs and learned about herbivores and carnivores.'
      },
      {
        'id': 'conv2',
        'title': 'Counting Practice',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'message_count': 8,
        'topics': ['Math', 'Numbers', 'Counting'],
        'summary': 'Emma practiced counting to 20 and learned about even and odd numbers.'
      },
      {
        'id': 'conv3',
        'title': 'Solar System Exploration',
        'timestamp': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'message_count': 15,
        'topics': ['Space', 'Planets', 'Astronomy'],
        'summary': 'Emma learned about the planets in our solar system and why Pluto is now considered a dwarf planet.'
      },
      {
        'id': 'conv4',
        'title': 'Animal Habitats',
        'timestamp': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'message_count': 10,
        'topics': ['Animals', 'Nature', 'Ecology'],
        'summary': 'Emma explored different animal habitats and learned about adaptation.'
      }
    ];
  }
  
  // For testing: Get mock conversation details
  Future<Map<String, dynamic>> getMockConversationDetails(String conversationId) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    final Map<String, dynamic> mockConversations = {
      'conv1': {
        'id': 'conv1',
        'title': 'Learning about Dinosaurs',
        'start_time': DateTime.now().subtract(const Duration(hours: 2, minutes: 30)).toIso8601String(),
        'end_time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'messages': [
          {
            'id': 'msg1',
            'sender': 'Emma',
            'content': 'Immy, can you tell me about dinosaurs?',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 30)).toIso8601String(),
          },
          {
            'id': 'msg2',
            'sender': 'Immy',
            'content': 'Of course, Emma! Dinosaurs were amazing creatures that lived millions of years ago. There were many different types of dinosaurs. Some were very big, and some were small.',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 29)).toIso8601String(),
          },
          {
            'id': 'msg3',
            'sender': 'Emma',
            'content': 'What\'s the biggest dinosaur?',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 28)).toIso8601String(),
          },
          {
            'id': 'msg4',
            'sender': 'Immy',
            'content': 'The biggest dinosaur we know about is called Argentinosaurus. It was as long as a swimming pool and as heavy as 12 elephants!',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 27)).toIso8601String(),
          },
          {
            'id': 'msg5',
            'sender': 'Emma',
            'content': 'Wow! Did dinosaurs eat people?',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 26)).toIso8601String(),
          },
          {
            'id': 'msg6',
            'sender': 'Immy',
            'content': 'No, dinosaurs and people never lived at the same time. Dinosaurs lived millions of years ago, and humans like you and me came much later.',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 25)).toIso8601String(),
          },
          {
            'id': 'msg7',
            'sender': 'Emma',
            'content': 'What did dinosaurs eat?',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 24)).toIso8601String(),
          },
          {
            'id': 'msg8',
            'sender': 'Immy',
            'content': 'Some dinosaurs ate plants, and we call them herbivores. Others ate meat, and we call them carnivores. For example, Triceratops was a herbivore, and T-Rex was a carnivore.',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 23)).toIso8601String(),
          },
          {
            'id': 'msg9',
            'sender': 'Emma',
            'content': 'I like T-Rex! It has tiny arms!',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 22)).toIso8601String(),
          },
          {
            'id': 'msg10',
            'sender': 'Immy',
            'content': 'Yes, T-Rex had small arms but very powerful jaws and legs. Those tiny arms were still strong though!',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 21)).toIso8601String(),
          },
          {
            'id': 'msg11',
            'sender': 'Emma',
            'content': 'What happened to all the dinosaurs?',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 20)).toIso8601String(),
          },
          {
            'id': 'msg12',
            'sender': 'Immy',
            'content': 'Scientists believe that a big asteroid hit Earth about 66 million years ago. It caused huge changes to the climate, and most dinosaurs couldn\'t survive. But not all dinosaurs disappeared - birds are actually descendants of dinosaurs!',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 19)).toIso8601String(),
          },
        ],
        'insights': {
          'topics': ['Dinosaurs', 'Paleontology', 'Science', 'Natural History'],
          'sentiment': 'Positive',
          'learning_points': [
            'Different types of dinosaurs existed (large and small)',
            'Herbivores vs. carnivores (diet differences)',
            'Dinosaurs and humans never coexisted',
            'Extinction event theory (asteroid impact)',
            'Birds as modern dinosaur descendants'
          ]
        }
      },
      'conv2': {
        'id': 'conv2',
        'title': 'Counting Practice',
        'start_time': DateTime.now().subtract(const Duration(days: 1, hours: 1)).toIso8601String(),
        'end_time': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'messages': [
          {
            'id': 'msg1',
            'sender': 'Emma',
            'content': 'Immy, can we count together?',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 1)).toIso8601String(),
          },
          {
            'id': 'msg2',
            'sender': 'Immy',
            'content': 'I\'d love to count with you, Emma! Let\'s start. 1...',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, minutes: 59)).toIso8601String(),
          },
          {
            'id': 'msg3',
            'sender': 'Emma',
            'content': '2, 3, 4!',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, minutes: 58)).toIso8601String(),
          },
          {
            'id': 'msg4',
            'sender': 'Immy',
            'content': 'Great job! Let\'s continue. 5, 6...',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, minutes: 57)).toIso8601String(),
          },
          {
            'id': 'msg5',
            'sender': 'Emma',
            'content': '7, 8, 9, 10!',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, minutes: 56)).toIso8601String(),
          },
          {
            'id': 'msg6',
            'sender': 'Immy',
            'content': 'Excellent! You\'re doing so well. Let\'s try counting to 20. After 10 comes...',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, minutes: 55)).toIso8601String(),
          },
          {
            'id': 'msg7',
            'sender': 'Emma',
            'content': '11, 12, 13, 14, 15, 16, 17, 18, 19, 20!',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, minutes: 54)).toIso8601String(),
          },
          {
            'id': 'msg8',
            'sender': 'Immy',
            'content': 'Amazing job, Emma! You counted all the way to 20 perfectly. Did you know that some numbers are called "even" and some are called "odd"? Even numbers can be divided into pairs, like 2, 4, 6, 8. Odd numbers can\'t, like 1, 3, 5, 7.',
            'timestamp': DateTime.now().subtract(const Duration(days: 1, minutes: 53)).toIso8601String(),
          },
        ],
        'insights': {
          'topics': ['Math', 'Numbers', 'Counting', 'Even and Odd'],
          'sentiment': 'Positive',
          'learning_points': [
            'Sequential counting from 1 to 20',
            'Introduction to even and odd numbers',
            'Positive reinforcement of counting skills'
          ]
        }
      }
    };
    
    if (mockConversations.containsKey(conversationId)) {
      return mockConversations[conversationId]!;
    } else {
      throw Exception('Conversation not found');
    }
  }
}
