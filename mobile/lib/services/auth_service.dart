import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String? _token;
  final ApiService _apiService = ApiService();

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isAdmin => _user?.role == 'admin';

  AuthService(String? initialToken) {
    if (initialToken != null) {
      _token = initialToken;
      _loadUser();
    }
  }

  Future<void> refreshUser() async {
    await _loadUser();
    notifyListeners();
  }

  Future<void> _loadUser() async {
    try {
      final response = await _apiService.get('/users/profile/');
      _user = User.fromJson(response);
      notifyListeners();
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    try {
      final response = await _apiService.post('/users/register/', {
        'username': username,
        'email': email,
        'password': password,
        'password2': password,
      });
      
      _token = response['access'];
      _user = User.fromJson(response['user']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _token!);
      notifyListeners();
      return {'success': true};
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.post('/users/login/', {
        'email': email,
        'password': password,
      });
      
      if (response.containsKey('email_not_verified') && response['email_not_verified'] == true) {
        return {'success': false, 'email_not_verified': true};
      }
      
      _token = response['access'];
      _user = User.fromJson(response['user']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _token!);
      notifyListeners();
      return {'success': true};
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> resendVerification(String email) async {
    try {
      await _apiService.post('/users/resend-verification/', {'email': email});
      return true;
    } catch (e) {
      print('Resend verification error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    notifyListeners();
  }
}
