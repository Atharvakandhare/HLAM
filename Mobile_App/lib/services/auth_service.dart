import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_service.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Removed as ApiService handles storage

class AuthService {
  final ApiService _api = ApiService();
  // final _storage = const FlutterSecureStorage(); // Removed as ApiService handles storage

  Future<User> login(String identifier, String password) async {
    final isEmail = identifier.contains('@');
    final Map<String, dynamic> body = {'password': password};

    if (isEmail) {
      body['email'] = identifier;
    } else {
      body['employeeId'] = identifier;
    }

    final response = await _api.post('/auth/login', body);

    // Save token
    await _api.setToken(response['token']);

    return User.fromJson(response['user']);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String employeeId,
    String role = 'employee',
    String? department,
  }) async {
    await _api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'employeeId': employeeId,
      'role': role,
      'department': department,
    });
  }

  Future<User?> getUser() async {
    try {
      final token = await _api.getToken();
      if (token == null) return null;


      final response = await _api.get('/auth/me');
      return User.fromJson(response['user'] ?? response);
    } catch (e) {
      debugPrint('AuthService Error during getUser: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', {});
    } catch (_) {
      // Ignore
    }
    await _api.deleteToken();
  }
}
