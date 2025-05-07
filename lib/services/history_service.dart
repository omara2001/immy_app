import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String _coachHistoryKey = 'coach_history';
  static const String _insightsHistoryKey = 'insights_history';
  
  // Save coach data with timestamp
  Future<void> saveCoachHistory(Map<String, dynamic> coachData) async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = await getCoachHistory();
    
    final historyItem = {
      'date': DateTime.now().toIso8601String(),
      'data': coachData,
    };
    
    historyList.insert(0, historyItem); // Add to beginning of list
    
    // Keep only the last 30 days
    if (historyList.length > 30) {
      historyList.removeRange(30, historyList.length);
    }
    
    await prefs.setString(_coachHistoryKey, jsonEncode(historyList));
  }
  
  // Get coach history
  Future<List<Map<String, dynamic>>> getCoachHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_coachHistoryKey);
    
    if (historyJson == null) {
      return [];
    }
    
    final List<dynamic> decoded = jsonDecode(historyJson);
    return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
  }
  
  // Save insights data with timestamp
  Future<void> saveInsightsHistory(Map<String, dynamic> insightsData) async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = await getInsightsHistory();
    
    final historyItem = {
      'date': DateTime.now().toIso8601String(),
      'data': insightsData,
    };
    
    historyList.insert(0, historyItem); // Add to beginning of list
    
    // Keep only the last 30 days
    if (historyList.length > 30) {
      historyList.removeRange(30, historyList.length);
    }
    
    await prefs.setString(_insightsHistoryKey, jsonEncode(historyList));
  }
  
  // Get insights history
  Future<List<Map<String, dynamic>>> getInsightsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_insightsHistoryKey);
    
    if (historyJson == null) {
      return [];
    }
    
    final List<dynamic> decoded = jsonDecode(historyJson);
    return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
  }
  
  // Get a specific coach history item by index
  Future<Map<String, dynamic>?> getCoachHistoryItem(int index) async {
    final history = await getCoachHistory();
    if (index >= 0 && index < history.length) {
      return history[index];
    }
    return null;
  }
  
  // Get a specific insights history item by index
  Future<Map<String, dynamic>?> getInsightsHistoryItem(int index) async {
    final history = await getInsightsHistory();
    if (index >= 0 && index < history.length) {
      return history[index];
    }
    return null;
  }
}