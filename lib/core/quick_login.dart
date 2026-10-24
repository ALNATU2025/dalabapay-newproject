// lib/core/quick_login.dart
// Signing back in with the PIN or fingerprint after the session expires.
//
// After a normal login the phone is enrolled (POST /api/auth/device/enroll)
// and the device key is kept in secure storage (Android Keystore / iOS
// Keychain) with the person's name and photo for the welcome-back screen.
// Fingerprint sign-in uses a second key that is only read after the phone
// confirms the fingerprint / face.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'api/api.dart';

class QuickProfile {
  final String userId;
  final String fullName;
  final String country;
  final String? avatar; // data URI
  const QuickProfile({required this.userId, required this.fullName, required this.country, this.avatar});

  String get firstName {
    final p = fullName.trim().split(RegExp(r'\s+'));
    return p.isEmpty || p.first.isEmpty ? 'there' : p.first;
  }

  Uint8List? get avatarBytes {
    final a = avatar;
    if (a == null || !a.contains(',')) return null;
    try {
      return base64Decode(a.split(',').last);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {'userId': userId, 'fullName': fullName, 'country': country, 'avatar': avatar};
  static QuickProfile? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['userId']?.toString() ?? '';
    if (id.isEmpty) return null;
    return QuickProfile(
      userId: id,
      fullName: j['fullName']?.toString() ?? '',
      country: j['country']?.toString() ?? 'NG',
      avatar: j['avatar']?.toString(),
    );
  }
}

class QuickLogin {
  QuickLogin._();

  static const _storage = FlutterSecureStorage();
  static const _kDevice = 'ql_device';
  static const _kBio = 'ql_bio';
  static const _kProfile = 'ql_profile';
  static final _auth = LocalAuthentication();

  static Future<String?> _read(String k) async {
    try {
      return await _storage.read(key: k);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String k, String? v) async {
    try {
      if (v == null) {
        await _storage.delete(key: k);
      } else {
        await _storage.write(key: k, value: v);
      }
    } catch (_) {}
  }

  /// The person this phone can sign back in, if any.
  static Future<QuickProfile?> profile() async {
    if (await _read(_kDevice) == null) return null;
    final raw = await _read(_kProfile);
    if (raw == null) return null;
    try {
      return QuickProfile.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> get available async => await profile() != null;

  /// After login: enrol this phone (once per person) and remember the
  /// name and photo. Never throws.
  static Future<void> remember(Map<String, dynamic> user) async {
    if (kIsWeb) return;
    try {
      final id = user['id']?.toString() ?? '';
      if (id.isEmpty) return;
      final current = await profile();
      if (current == null || current.userId != id || await _read(_kDevice) == null) {
        final r = await api.post('/api/auth/device/enroll', {
          'deviceName': defaultTargetPlatform == TargetPlatform.iOS ? 'iPhone' : 'Android phone',
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        });
        final key = (r is Map ? r['deviceKey'] : null)?.toString();
        if (key == null) return;
        await _write(_kDevice, key);
        await _write(_kBio, null);
      }
      await updateProfile(user);
    } catch (e) {
      debugPrint('Quick sign-in not set up: $e');
    }
  }

  /// Keeps the name and photo on the welcome-back screen up to date.
  static Future<void> updateProfile(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final current = await profile();
    if (current != null && current.userId != id) return;
    final p = QuickProfile(
      userId: id,
      fullName: user['fullName']?.toString() ?? '',
      country: user['country']?.toString() ?? 'NG',
      avatar: user.containsKey('avatar') ? user['avatar']?.toString() : current?.avatar,
    );
    await _write(_kProfile, jsonEncode(p.toJson()));
  }

  /// Forget this phone's quick sign-in ("Not you?").
  static Future<void> forget() async {
    final key = await _read(_kDevice);
    if (key != null && api.hasToken) {
      try {
        await api.post('/api/auth/device/remove', {'deviceKey': key});
      } catch (_) {}
    }
    await _write(_kDevice, null);
    await _write(_kBio, null);
    await _write(_kProfile, null);
  }

  /// { token, user } on success. Throws [ApiException].
  static Future<Map<String, dynamic>> signInWithPin(String pin) async {
    final key = await _read(_kDevice);
    if (key == null) throw const ApiException(401, 'DEVICE_REVOKED', 'Please log in with your password.');
    final r = await api.post('/api/auth/quick-login', {'deviceKey': key, 'pin': pin});
    return Map<String, dynamic>.from(r as Map);
  }

  // ── Fingerprint / face ───────────────────────────────────

  static Future<bool> get biometricsSupported async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> get biometricEnabled async => await _read(_kBio) != null;

  /// Asks the phone for the fingerprint / face. True when it matched.
  static Future<bool> _check(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric check failed: ${e.code}');
      return false;
    }
  }

  /// Turns on fingerprint sign-in (needs a signed-in session and the PIN).
  static Future<bool> enableBiometric(String pin) async {
    final key = await _read(_kDevice);
    if (key == null) return false;
    if (!await _check('Confirm to turn on fingerprint sign-in')) return false;
    final r = await api.post('/api/auth/device/biometric', {'deviceKey': key, 'pin': pin});
    final bio = (r is Map ? r['bioKey'] : null)?.toString();
    if (bio == null) return false;
    await _write(_kBio, bio);
    return true;
  }

  static Future<void> disableBiometric() => _write(_kBio, null);

  /// { token, user } after a fingerprint / face match, or null if cancelled.
  static Future<Map<String, dynamic>?> signInWithBiometric() async {
    final key = await _read(_kDevice);
    final bio = await _read(_kBio);
    if (key == null || bio == null) return null;
    if (!await _check('Sign in to Dalabapay')) return null;
    final r = await api.post('/api/auth/quick-login', {'deviceKey': key, 'bioKey': bio});
    return Map<String, dynamic>.from(r as Map);
  }

  /// When the server says the key no longer works (password changed).
  static Future<void> revoked() async {
    await _write(_kDevice, null);
    await _write(_kBio, null);
  }
}

/// Blocks screenshots and the app-switcher preview on sensitive screens
/// (Android). No-op elsewhere.
class SecureScreen {
  SecureScreen._();
  static const _channel = MethodChannel('dalabapay/secure');
  static int _depth = 0;

  static Future<void> enter() async {
    _depth++;
    if (_depth == 1) await _set(true);
  }

  static Future<void> exit() async {
    if (_depth > 0) _depth--;
    if (_depth == 0) await _set(false);
  }

  static Future<void> _set(bool on) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('setSecure', {'on': on});
    } catch (_) {}
  }
}
