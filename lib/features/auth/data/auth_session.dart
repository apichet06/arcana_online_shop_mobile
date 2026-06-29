import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:arcana_online_shop_mobile/config/app_config.dart';
import 'package:arcana_online_shop_mobile/features/auth/domain/auth_user.dart';

class AuthSession extends ChangeNotifier {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const _accessTokenKey = 'arcana_access_token';
  static const _refreshCookieKey = 'arcana_refresh_cookie';
  static const _userKey = 'arcana_auth_user';
  static const _cookieName = 'arcana_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshCookie;
  AuthUser? _user;
  bool _initialized = false;
  Future<bool>? _refreshFuture;

  bool get initialized => _initialized;
  bool get isLoggedIn => _accessToken != null && _user != null;
  String? get accessToken => _accessToken;
  AuthUser? get user => _user;

  Future<void> initialize() async {
    if (_initialized) return;

    _accessToken = await _storage.read(key: _accessTokenKey);
    _refreshCookie = await _storage.read(key: _refreshCookieKey);
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(userJson);
        if (decoded is Map<String, dynamic>) {
          _user = AuthUser.fromJson(decoded);
        }
      } catch (_) {
        await clear();
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _buildDio().post<dynamic>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    await _saveAuthResponse(response);
  }

  Future<void> loginWithGoogleAccessToken(String accessToken) async {
    final response = await _buildDio().post<dynamic>(
      '/auth/google',
      data: {'access_token': accessToken},
    );

    await _saveAuthResponse(response);
  }

  Future<void> loginWithFacebookAccessToken(String accessToken) async {
    final response = await _buildDio().post<dynamic>(
      '/auth/facebook',
      data: {'access_token': accessToken},
    );

    await _saveAuthResponse(response);
  }

  Future<void> register(Map<String, dynamic> payload) async {
    final response = await _buildDio().post<dynamic>(
      '/auth/register',
      data: payload,
    );

    await _saveAuthResponse(response);
  }

  Future<bool> refreshAccessToken() {
    _refreshFuture ??= _refreshAccessToken().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  // อัปเดต username ใน session หลังแก้โปรไฟล์สำเร็จ
  // เซฟลง secure storage ด้วยเพื่อให้ชื่อถูกต้องแม้ restart แอป
  Future<void> updateUsername(String username) async {
    if (_user == null) return;
    _user = AuthUser(
      id: _user!.id,
      username: username,
      email: _user!.email,
      avatar: _user!.avatar,
    );
    await _storage.write(key: _userKey, value: jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final cookie = _refreshCookie;
      if (cookie != null && cookie.isNotEmpty) {
        await _buildDio().post<dynamic>(
          '/auth/logout',
          options: Options(headers: {'Cookie': cookie}),
        );
      }
    } catch (_) {
      // Local logout should continue even when the revoke request fails.
    } finally {
      await clear();
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshCookie = null;
    _user = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshCookieKey),
      _storage.delete(key: _userKey),
    ]);
    notifyListeners();
  }

  Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: const {'Accept': 'application/json'},
      ),
    );
  }

  Future<bool> _refreshAccessToken() async {
    final cookie = _refreshCookie;
    if (cookie == null || cookie.isEmpty) {
      await clear();
      return false;
    }

    try {
      final response = await _buildDio().post<dynamic>(
        '/auth/refresh',
        options: Options(headers: {'Cookie': cookie}),
      );
      await _saveAuthResponse(response);
      return true;
    } catch (_) {
      await clear();
      return false;
    }
  }

  Future<void> _saveAuthResponse(Response<dynamic> response) async {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Auth response is not a JSON object');
    }

    final token = data['token']?.toString();
    final userJson = data['user'];
    if (token == null ||
        token.isEmpty ||
        userJson is! Map<String, dynamic>) {
      throw const FormatException('Auth response is missing token or user');
    }

    final refreshCookie = _extractRefreshCookie(response);
    _accessToken = token;
    _user = AuthUser.fromJson(userJson);
    if (refreshCookie != null) _refreshCookie = refreshCookie;

    await _storage.write(key: _accessTokenKey, value: _accessToken);
    await _storage.write(key: _userKey, value: jsonEncode(_user!.toJson()));
    if (_refreshCookie != null) {
      await _storage.write(key: _refreshCookieKey, value: _refreshCookie);
    }

    notifyListeners();
  }

  String? _extractRefreshCookie(Response<dynamic> response) {
    final cookies = response.headers.map['set-cookie'] ?? const [];
    for (final cookie in cookies) {
      final firstPart = cookie.split(';').first.trim();
      if (firstPart.startsWith('$_cookieName=')) return firstPart;
    }
    return null;
  }
}
