import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import '../core/env.dart';
import 'models.dart';

const _refreshKey = 'itilms.refreshToken';

class AuthService extends ChangeNotifier {
  AuthService() {
    api = ApiClient(readAccessToken: () => _accessToken, refresh: refreshAccessToken);
  }

  late final ApiClient api;
  final _storage = const FlutterSecureStorage();

  String? _accessToken;
  AppUser? user;
  bool ready = false;

  /// Plain client for the refresh call itself, so it never loops through the 401 handler.
  final _bare = Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 15)));

  /// One in-flight refresh shared by every caller: refresh tokens rotate, and reusing one revokes the session.
  Future<String?>? _refreshing;

  bool get signedIn => user != null && _accessToken != null;

  Future<void> _apply(AuthResponse auth) async {
    _accessToken = auth.accessToken;
    user = auth.user;
    await _storage.write(key: _refreshKey, value: auth.refreshToken);
    notifyListeners();
  }

  Future<void> _clear() async {
    _accessToken = null;
    user = null;
    await _storage.delete(key: _refreshKey);
    notifyListeners();
  }

  /// Called once at launch: a stored refresh token signs the person back in silently.
  Future<void> bootstrap() async {
    try {
      await refreshAccessToken();
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<String?> refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final stored = await _storage.read(key: _refreshKey);
    if (stored == null) return null;
    try {
      final res = await _bare.post('/api/auth/refresh', data: {'refreshToken': stored});
      final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
      await _apply(auth);
      return auth.accessToken;
    } catch (_) {
      await _clear();
      return null;
    }
  }

  Future<void> login(String identifier, String password) async {
    final res = await api.dio.post('/api/auth/login', data: {'identifier': identifier, 'password': password});
    await _apply(AuthResponse.fromJson(res.data as Map<String, dynamic>));
  }

  Future<void> logout() async {
    final stored = await _storage.read(key: _refreshKey);
    await _clear();
    if (stored != null) {
      // Best effort: the session is already gone on this device either way.
      await _bare.post('/api/auth/logout', data: {'refreshToken': stored}).then((_) {}, onError: (_) {});
    }
  }
}
