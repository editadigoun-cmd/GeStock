import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: const String.fromEnvironment(
                'NEON_AUTH_URL',
                defaultValue: 'https://gestock-auth-proxy.ccds22431.workers.dev/auth',
              ),
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 25),
              sendTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json'},
            )),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _cookieKey = 'gestock_auth_cookie';

  Future<void> signIn(String email, String password) async {
    final response = await _dio.post(
      '/sign-in/email',
      data: {'email': email.trim(), 'password': password},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception(_message(response.data));
    }
    await _saveCookie(response);
    await _requireSession();
  }

  Future<void> signUp(String name, String email, String password) async {
    final response = await _dio.post(
      '/sign-up/email',
      data: {'name': name.trim(), 'email': email.trim(), 'password': password},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception(_message(response.data));
    }
    await _saveCookie(response);
    await _requireSession();
  }

  Future<void> _requireSession() async {
    final cookie = await _storage.read(key: _cookieKey);
    if (cookie == null || cookie.isEmpty) {
      throw Exception('Le compte a été traité, mais aucune session sécurisée n’a été retournée. Réessayez de vous connecter.');
    }
  }

  Future<String> getAccessToken() async {
    final cookie = await _storage.read(key: _cookieKey);
    if (cookie == null) throw Exception('Session absente.');
    final response = await _dio.get(
      '/token',
      options: Options(
        headers: {'Cookie': cookie},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception('Impossible de renouveler la session.');
    }
    final data = response.data;
    if (data is Map && data['token'] is String) return data['token'] as String;
    throw Exception('Le service n’a pas retourné de jeton API.');
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
    final cookie = await _storage.read(key: _cookieKey);
    if (cookie != null) {
      try {
        await _dio.post('/sign-out', options: Options(headers: {'Cookie': cookie}));
      } catch (_) {}
    }
    await _storage.delete(key: _cookieKey);
  }

  Future<void> _saveCookie(Response response) async {
    final values = response.headers.map['set-cookie'] ?? [];
    if (values.isEmpty) return;
    final cookie = values
        .map((v) => v.split(';').first)
        .where((v) => v.contains('='))
        .join('; ');
    if (cookie.isNotEmpty) {
      await _storage.write(key: _cookieKey, value: cookie);
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
