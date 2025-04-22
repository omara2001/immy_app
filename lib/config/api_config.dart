class ApiConfig {
  // Base URL for API calls
  static const String baseUrl = 'https://immy-database.czso7gvuv5td.eu-north-1.rds.amazonaws.com/api';
  
  // API version
  static const String apiVersion = 'v1';
  
  // Full API URL with version
  static String get apiUrl => '$baseUrl/$apiVersion';
  
  // Timeout duration in seconds
  static const int defaultTimeout = 30;
} 