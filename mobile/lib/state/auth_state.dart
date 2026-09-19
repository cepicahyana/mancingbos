import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/models.dart';

class AuthState extends ChangeNotifier {
  AuthState(this.api);

  final ApiClient api;
  User? user;
  bool ready = false;
  String? error;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString('token');
    if (api.token != null) {
      try {
        final res = await api.get('/api/auth/me');
        user = User.fromJson(res['data'] as Map<String, dynamic>);
      } catch (_) {
        await logout();
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    error = null;
    notifyListeners();
    final res = await api.post('/api/auth/login', {'email': email, 'password': password});
    await _persist(res);
  }

  Future<void> register(String name, String email, String password, String role) async {
    error = null;
    notifyListeners();
    final res = await api.post('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    await _persist(res);
  }

  Future<void> _persist(Map<String, dynamic> res) async {
    final data = res['data'] as Map<String, dynamic>;
    api.token = '${data['token']}';
    user = User.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token!);
    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (api.token == null) return;
    try {
      final res = await api.get('/api/auth/me');
      user = User.fromJson(res['data'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
