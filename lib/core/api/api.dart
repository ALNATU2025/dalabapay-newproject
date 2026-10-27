// lib/core/api/api.dart
// HTTP client for the DalabaPay backend (newproject-backend).
//
// The server address comes from --dart-define=API_URL=… and defaults to
// the live server on Render. For a backend on your own computer use
// --dart-define=API_URL=http://10.0.2.2:4000 (Android emulator). Every response is { success, data } or
// { success:false, code, message }; errors become [ApiException].
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  ApiConfig._();
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://newproject-backend-bod8.onrender.com',
  );
  // Render's free plan can take ~50 s to wake up.
  static const Duration timeout = Duration(seconds: 70);
}

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final List<dynamic> errors;
  const ApiException(this.status, this.code, this.message,
      [this.errors = const []]);

  bool get isNetwork => status == 0;

  /// First field error message, if the server sent any.
  String? fieldError(String field) {
    for (final e in errors) {
      if (e is Map && e['field'] == field) return e['message']?.toString();
    }
    return null;
  }

  @override
  String toString() => message;
}

/// A readable message for any error thrown while calling the API.
String errorMessage(Object e) {
  if (e is ApiException) return e.message;
  // Not from the server: print it so it shows in the debug console.
  debugPrint('Unexpected error: $e');
  if (kDebugMode) return 'Something went wrong: $e';
  return 'Something went wrong. Please try again.';
}

class Api {
  Api._();
  static final Api instance = Api._();

  static const _tokenKey = 'dp_token';
  final _storage = const FlutterSecureStorage();
  final http.Client _client = http.Client();
  String? _token;

  /// Called when the server rejects the saved session (expired, password
  /// changed, account deactivated).
  void Function()? onUnauthorized;

  /// Small saved flags (e.g. onboarding seen).
  Future<bool> readFlag(String key) async {
    try {
      return (await _storage.read(key: 'flag_$key')) == '1';
    } catch (_) {
      return false;
    }
  }

  /// Sets (or with [on] false, clears) a small saved flag.
  Future<void> setFlag(String key, {bool on = true}) async {
    try {
      if (on) {
        await _storage.write(key: 'flag_$key', value: '1');
      } else {
        await _storage.delete(key: 'flag_$key');
      }
    } catch (_) {}
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> loadToken() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    await _loadDeviceId();
  }

  // A random id for this install, kept across logouts, so the server can
  // tell the person (and the admins) when the account signs in on a new
  // phone. It identifies nothing else about the phone.
  static const _deviceKey = 'dp_device_id';
  String? _deviceId;

  Future<void> _loadDeviceId() async {
    if (kIsWeb || _deviceId != null) return;
    try {
      var id = await _storage.read(key: _deviceKey);
      if (id == null || id.length < 16) {
        final r = Random.secure();
        id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
        await _storage.write(key: _deviceKey, value: id);
      }
      _deviceId = id;
    } catch (_) {}
  }

  static String get _deviceName {
    if (kIsWeb) return 'Web browser';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isAndroid) return 'Android phone';
    return Platform.operatingSystem;
  }

  /// Saves the token. With [persist] false ("Remember me" off) it is kept
  /// only until the app is closed.
  Future<void> setToken(String token, {bool persist = true}) async {
    _token = token;
    try {
      if (persist) {
        await _storage.write(key: _tokenKey, value: token);
      } else {
        await _storage.delete(key: _tokenKey);
      }
    } catch (_) {}
  }

  Future<void> clearToken() async {
    _token = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
    });
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    return q.isEmpty ? base : base.replace(queryParameters: q);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $_token',
        if (_deviceId != null) ...{
          'X-Device-Id': _deviceId!,
          'X-Device-Name': _deviceName,
          'X-Device-Platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(
      () => _client.post(_uri(path),
          headers: _headers, body: jsonEncode(body ?? const {})));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _send(
      () => _client.patch(_uri(path),
          headers: _headers, body: jsonEncode(body ?? const {})));

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _send(
      () => _client.put(_uri(path),
          headers: _headers, body: jsonEncode(body ?? const {})));

  Future<dynamic> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  /// Wakes the server (Render sleeps when idle). Never throws.
  Future<void> warmUp() async {
    try {
      await _client.get(_uri('/health')).timeout(ApiConfig.timeout);
    } catch (_) {}
  }

  /// Raw text download (CSV export).
  Future<String> getText(String path, {Map<String, dynamic>? query}) async {
    final res = await _raw(() => _client.get(_uri(path, query), headers: _headers));
    if (res.statusCode >= 400) _throw(res);
    return utf8.decode(res.bodyBytes);
  }

  Future<http.Response> _raw(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException(
          0, 'TIMEOUT', 'The server is taking too long. Please try again.');
    } on SocketException {
      throw const ApiException(0, 'NETWORK',
          'Can\'t reach DalabaPay. Check your internet connection.');
    } on http.ClientException catch (e) {
      debugPrint('Network error: $e');
      throw const ApiException(0, 'NETWORK',
          'Can\'t reach DalabaPay. Check your internet connection.');
    } on HandshakeException catch (e) {
      // Usually a wrong date/time on the phone, or a network that
      // intercepts HTTPS.
      debugPrint('Secure connection failed: $e');
      throw const ApiException(0, 'NETWORK',
          'Secure connection failed. Check the date and time on your phone, or try another network.');
    } on IOException catch (e) {
      debugPrint('Network error: $e');
      throw const ApiException(0, 'NETWORK',
          'Can\'t reach DalabaPay. Check your internet connection.');
    }
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final res = await _raw(call);
    if (res.statusCode >= 400) _throw(res);
    final body = _decode(res);
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  dynamic _decode(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Never _throw(http.Response res) {
    final body = _decode(res);
    final code = body is Map ? (body['code']?.toString() ?? 'ERROR') : 'ERROR';
    final message = body is Map && body['message'] != null
        ? body['message'].toString()
        : (res.statusCode >= 500
            ? 'The server had a problem. Please try again shortly.'
            : 'Request failed (${res.statusCode}).');
    final errors = body is Map && body['errors'] is List
        ? body['errors'] as List
        : const [];
    debugPrint('API ${res.request?.method} ${res.request?.url.path} → ${res.statusCode} $code: $message');
    if (res.statusCode == 401 && hasToken && code != 'INVALID_CREDENTIALS') {
      clearToken();
      onUnauthorized?.call();
    }
    throw ApiException(res.statusCode, code, message, errors);
  }
}

/// Shorthand used by screens: `api.get('/api/me')`.
Api get api => Api.instance;
