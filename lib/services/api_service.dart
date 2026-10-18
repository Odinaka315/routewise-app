import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/api_models.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _kAccessTokenKey = 'routewise_access_token';
  static const _kRefreshTokenKey = 'routewise_refresh_token';
  static const _kUserKey = 'routewise_cached_user';

  AuthTokens? _tokens;
  AuthUser? _currentUser;
  bool _initialized = false;

  AuthTokens? get tokens => _tokens;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _tokens?.accessToken != null && _tokens!.accessToken.isNotEmpty;

  /// Loads persisted tokens and user details from SharedPreferences.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_kAccessTokenKey);
    final refresh = prefs.getString(_kRefreshTokenKey);
    final userJson = prefs.getString(_kUserKey);

    if (access != null && refresh != null) {
      _tokens = AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresIn: 900,
        refreshExpiresIn: 2592000,
      );
    }
    if (userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
    }
    _initialized = true;
  }

  Future<void> _persistSession(AuthTokens tokens, [AuthUser? user]) async {
    _tokens = tokens;
    if (user != null) _currentUser = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, tokens.accessToken);
    await prefs.setString(_kRefreshTokenKey, tokens.refreshToken);
    if (_currentUser != null) {
      await prefs.setString(_kUserKey, jsonEncode(_currentUser!.toJson()));
    }
  }

  Future<void> _clearSession() async {
    _tokens = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
    await prefs.remove(_kUserKey);
  }

  // ==========================================
  // HTTP Helpers
  // ==========================================

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.https(
      AppConfig.linkDomain,
      cleanPath,
      queryParameters?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> _headers({bool requiresAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth && _tokens != null) {
      headers['Authorization'] = 'Bearer ${_tokens!.accessToken}';
    }
    return headers;
  }

  ApiException _handleError(Object error, {int? statusCode, String? responseBody}) {
    if (error is SocketException) {
      return ApiException(
        'Unable to connect to Routewise server. Please check your internet connection.',
        isNetworkError: true,
      );
    }
    if (error is TimeoutException) {
      return ApiException(
        'The server took too long to reply. If it was sleeping, please retry in a few moments.',
        isTimeout: true,
      );
    }
    if (error is ApiException) {
      return error;
    }

    String message = 'An unexpected error occurred.';
    if (responseBody != null && responseBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          if (decoded['detail'] != null) {
            final detail = decoded['detail'];
            if (detail is String) {
              message = detail;
            } else if (detail is List && detail.isNotEmpty) {
              final first = detail.first;
              if (first is Map && first['msg'] != null) {
                message = first['msg'].toString();
              } else {
                message = detail.toString();
              }
            }
          } else if (decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        }
      } catch (_) {
        message = responseBody;
      }
    }

    return ApiException(message, statusCode: statusCode);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) async {
    await init();
    final url = _uri(path, queryParameters);
    final headers = _headers(requiresAuth: requiresAuth);

    http.Response response;
    try {
      final reqFuture = switch (method.toUpperCase()) {
        'GET' => http.get(url, headers: headers),
        'POST' => http.post(url, headers: headers, body: body != null ? jsonEncode(body) : null),
        'PATCH' => http.patch(url, headers: headers, body: body != null ? jsonEncode(body) : null),
        'DELETE' => http.delete(url, headers: headers),
        _ => throw UnsupportedError('Method $method not supported'),
      };

      response = await reqFuture.timeout(AppConfig.requestTimeout);
    } catch (e) {
      throw _handleError(e);
    }

    // Attempt token refresh on 401 if authorized request
    if (response.statusCode == 401 && requiresAuth && retryOnUnauthorized && _tokens?.refreshToken != null) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return _send(
          method,
          path,
          body: body,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          retryOnUnauthorized: false,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    throw _handleError(
      ApiException('Request failed with status ${response.statusCode}'),
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refresh = _tokens?.refreshToken;
    if (refresh == null) return false;

    try {
      final url = _uri('/auth/refresh');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newTokens = AuthTokens.fromJson(data);
        await _persistSession(newTokens, _currentUser);
        return true;
      }
    } catch (_) {}

    await _clearSession();
    return false;
  }

  // ==========================================
  // Auth API
  // ==========================================

  /// Signup: POST /auth/signup
  Future<AuthUser> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      body['display_name'] = displayName.trim();
    }

    final data = await _send('POST', '/auth/signup', body: body, requiresAuth: false);
    return AuthUser.fromJson(data as Map<String, dynamic>);
  }

  /// Login: POST /auth/login
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final data = await _send(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      requiresAuth: false,
    );

    final tokens = AuthTokens.fromJson(data as Map<String, dynamic>);
    await _persistSession(tokens);

    // Fetch user details
    try {
      final user = await getMe();
      await _persistSession(tokens, user);
    } catch (_) {}

    return tokens;
  }

  /// Get Current User: GET /auth/me
  Future<AuthUser> getMe() async {
    final data = await _send('GET', '/auth/me');
    final user = AuthUser.fromJson(data as Map<String, dynamic>);
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(user.toJson()));
    return user;
  }

  /// Resend Verification: POST /auth/resend-verification
  Future<String> resendVerification({required String email}) async {
    final data = await _send(
      'POST',
      '/auth/resend-verification',
      body: {'email': email.trim()},
      requiresAuth: false,
    );
    if (data is Map && data['message'] != null) {
      return data['message'] as String;
    }
    return 'If an account exists, a new verification link was sent.';
  }

  /// Verify Email: POST /auth/verify-email
  Future<String> verifyEmail({required String token}) async {
    final data = await _send(
      'POST',
      '/auth/verify-email',
      body: {'token': token.trim()},
      requiresAuth: false,
    );
    if (data is Map && data['message'] != null) {
      return data['message'] as String;
    }
    return 'Email verified. You can now log in.';
  }

  /// Forgot Password: POST /auth/forgot-password
  Future<String> forgotPassword({required String email}) async {
    final data = await _send(
      'POST',
      '/auth/forgot-password',
      body: {'email': email.trim()},
      requiresAuth: false,
    );
    if (data is Map && data['message'] != null) {
      return data['message'] as String;
    }
    return 'If that email is registered, a password reset link has been sent.';
  }

  /// Reset Password: POST /auth/reset-password
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final data = await _send(
      'POST',
      '/auth/reset-password',
      body: {
        'token': token.trim(),
        'new_password': newPassword,
      },
      requiresAuth: false,
    );
    if (data is Map && data['message'] != null) {
      return data['message'] as String;
    }
    return 'Password updated. You can now log in.';
  }

  /// Logout (this device): POST /auth/logout
  Future<void> logout() async {
    try {
      if (isAuthenticated) {
        await _send('POST', '/auth/logout');
      }
    } catch (_) {}
    await _clearSession();
  }

  /// Logout All Devices: POST /auth/logout-all
  Future<void> logoutAll() async {
    try {
      if (isAuthenticated) {
        await _send('POST', '/auth/logout-all');
      }
    } catch (_) {}
    await _clearSession();
  }

  // ==========================================
  // Trips API
  // ==========================================

  /// List user trips: GET /trips
  Future<Map<String, dynamic>> listTrips({
    bool? starred,
    String? q,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (starred != null) query['starred'] = starred;
    if (q != null && q.isNotEmpty) query['q'] = q;

    final data = await _send('GET', '/trips', queryParameters: query);
    return data as Map<String, dynamic>;
  }

  /// Get trip detail: GET /trips/{id}
  Future<Map<String, dynamic>> getTrip(String tripId) async {
    final data = await _send('GET', '/trips/$tripId');
    return data as Map<String, dynamic>;
  }

  /// Create and solve trip: POST /trips
  Future<Map<String, dynamic>> createTrip({
    required String title,
    required List<Map<String, dynamic>> stops,
    int startIndex = 0,
    bool openPath = true,
    String preset = 'balanced',
  }) async {
    final body = {
      'title': title,
      'stops': stops,
      'start_index': startIndex,
      'open_path': openPath,
      'preset': preset,
    };
    final data = await _send('POST', '/trips', body: body);
    return data as Map<String, dynamic>;
  }

  /// Patch trip (rename or star/unstar): PATCH /trips/{id}
  Future<Map<String, dynamic>> patchTrip(
    String tripId, {
    String? title,
    bool? isStarred,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (isStarred != null) body['is_starred'] = isStarred;

    final data = await _send('PATCH', '/trips/$tripId', body: body);
    return data as Map<String, dynamic>;
  }

  /// Delete trip: DELETE /trips/{id}
  Future<void> deleteTrip(String tripId) async {
    await _send('DELETE', '/trips/$tripId');
  }

  /// Get trip run history: GET /trips/{id}/runs
  Future<List<dynamic>> getTripRuns(String tripId) async {
    final data = await _send('GET', '/trips/$tripId/runs');
    return data as List<dynamic>;
  }

  // ==========================================
  // Geocode Search API
  // ==========================================

  /// Geocode search: GET /geocode/search
  Future<List<GeocodeResult>> geocodeSearch(String query, {int limit = 5}) async {
    final data = await _send(
      'GET',
      '/geocode/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .map((item) => GeocodeResult.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
