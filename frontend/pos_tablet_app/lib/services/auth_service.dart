import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/network/api_client.dart';
import '../data/local/app_database.dart';

class AuthService {
  AuthService({required this.apiClient, required this.database});

  final ApiClient apiClient;
  final AppDatabase database;

  Future<bool> restoreSession() async {
    final token = await database.getSetting('auth_token');
    if (token == null || token.isEmpty) {
      return false;
    }

    apiClient.setToken(token);

    try {
      final userResponse = await apiClient.getMap('/auth/me');
      final roleData = userResponse['role'];
      final role = (roleData is Map) ? (roleData['role_name'] ?? roleData['name'] ?? 'Kasir') : 'Kasir';
      
      // Block non-admin on Web
      if (kIsWeb && role.toString().toLowerCase() == 'kasir') {
        apiClient.clearToken();
        await database.setSetting('auth_token', '');
        await database.setSetting('auth_user_email', '');
        await database.setSetting('auth_user_role', '');
        return false;
      }
      
      await database.setSetting('auth_user_role', role.toString());
      return true;
    } catch (_) {
      apiClient.clearToken();
      await database.setSetting('auth_token', '');
      await database.setSetting('auth_user_email', '');
      await database.setSetting('auth_user_role', '');
      return false;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final response = await apiClient.post('/auth/login', {
      'email': email,
      'password': password,
      'device_name': deviceName,
    });

    final token = (response['token'] ?? '') as String;
    if (token.isEmpty) {
      throw Exception('Token tidak diterima dari server.');
    }

    apiClient.setToken(token);
    await database.setSetting('auth_token', token);
    await database.setSetting('auth_user_email', email);
    
    final userMap = response['user'] as Map<String, dynamic>? ?? {};
    final roleData = userMap['role'];
    final role = (roleData is Map) ? (roleData['role_name'] ?? roleData['name'] ?? 'Kasir') : 'Kasir';
    
    // Block non-admin on Web
    if (kIsWeb && role.toString().toLowerCase() == 'kasir') {
      apiClient.clearToken();
      await database.setSetting('auth_token', '');
      await database.setSetting('auth_user_email', '');
      await database.setSetting('auth_user_role', '');
      throw Exception('Akses website hanya untuk Admin (Owner/Manager). Kasir silakan gunakan aplikasi tablet.');
    }
    
    await database.setSetting('auth_user_role', role.toString());

    return response;
  }

  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout', {});
    } catch (_) {
      // Do not block local logout when server is unreachable.
    }

    apiClient.clearToken();
    await database.setSetting('auth_token', '');
    await database.setSetting('auth_user_email', '');
    await database.setSetting('auth_user_role', '');
  }

  Future<String> currentUserEmail() async {
    return (await database.getSetting('auth_user_email')) ?? '-';
  }

  Future<String> currentUserRole() async {
    return (await database.getSetting('auth_user_role')) ?? 'Kasir';
  }
}
