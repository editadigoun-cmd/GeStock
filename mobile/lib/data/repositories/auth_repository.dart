import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: const String.fromEnvironment(
                'GESTOCK_API_URL',
                defaultValue: 'https://gestock-api.ccds22431.workers.dev',
              ),
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 25),
              sendTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json'},
              validateStatus: (status) => status != null && status < 500,
            )),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'gestock_auth_token';
  static const _legacyCookieKey = 'gestock_auth_cookie';

  Future<void> signIn(String email, String password) async {
    await _removeLegacyCredential();
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception(_message(response.data));
    }
    await _saveToken(response.data);
    await _requireSession();
  }

  Future<void> signUp(String name, String email, String password) async {
    await _removeLegacyCredential();
    final response = await _dio.post(
      '/auth/register',
      data: {'name': name.trim(), 'email': email.trim(), 'password': password},
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception(_message(response.data));
    }
    await _saveToken(response.data);
    await _requireSession();
  }

  Future<void> _saveToken(dynamic data) async {
    if (data is! Map || data['data'] is! Map || data['data']['token'] is! String) {
      throw Exception('Le service GeStock n’a pas retourné de session valide.');
    }
    final token = data['data']['token'] as String;
    if (token.isEmpty) throw Exception('Session invalide.');
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> _removeLegacyCredential() async {
    await _storage.delete(key: _legacyCookieKey);
  }

  Future<void> _requireSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      throw Exception('Le compte a été traité, mais aucune session sécurisée n’a été enregistrée. Réessayez.');
    }
    final response = await _dio.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      await _storage.delete(key: _tokenKey);
      throw Exception('La session GeStock n’a pas pu être validée. Connectez-vous à nouveau.');
    }
  }

  Future<String> getAccessToken() async {
    await _removeLegacyCredential();
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) throw Exception('Session absente.');
    final response = await _dio.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      await _storage.delete(key: _tokenKey);
      throw Exception('Session expirée. Connectez-vous à nouveau.');
    }
    return token;
  }

  Future<bool> hasValidSession() async {
    try {
      await getAccessToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      try {
        await _dio.post('/auth/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
      } catch (_) {}
    }
    await _storage.delete(key: _tokenKey);
    await _removeLegacyCredential();
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final token = await getAccessToken();
    final response = await _dio.post(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception(_message(response.data));
    }
  }

  String _message(dynamic data) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg is String) return msg;
    }
    return 'Connexion impossible. Vérifiez vos identifiants et réessayez.';
  }
}
