import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';
  static const Duration timeout = Duration(seconds: 5); // 5 second timeout

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    final url = '$baseUrl$endpoint';
    print('📤 GET: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(timeout);
      
      print('📥 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded;
      }
      
      throw Exception('Server error: ${response.statusCode}');
    } on TimeoutException {
      print('⏰ Request timed out');
      throw Exception('Connection timeout. Please check your network.');
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, dynamic data) async {
    final url = '$baseUrl$endpoint';
    print('📤 POST: $url');
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: json.encode(data),
      ).timeout(timeout);
      
      print('📥 Status: ${response.statusCode}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
      throw Exception('Server error: ${response.statusCode}');
    } on TimeoutException {
      print('⏰ Request timed out');
      throw Exception('Connection timeout. Please check your network.');
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  Future<dynamic> put(String endpoint, dynamic data) async {
    final url = '$baseUrl$endpoint';
    
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: json.encode(data),
      ).timeout(timeout);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw Exception('Server error: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your network.');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    final url = '$baseUrl$endpoint';
    
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(timeout);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw Exception('Server error: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your network.');
    }
  }

  Future<dynamic> deleteWithBody(String endpoint, dynamic data) async {
    final url = '$baseUrl$endpoint';
    
    try {
      final request = http.Request('DELETE', Uri.parse(url));
      request.headers.addAll(await _getHeaders());
      request.body = json.encode(data);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw Exception('Server error: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your network.');
    }
  }
}
