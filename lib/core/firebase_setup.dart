// lib/core/firebase_setup.dart
// Firebase is used only for sign-up SMS codes (Phone Auth). The server
// decides when SMS is used (SIGNUP_VERIFICATION=sms); otherwise the email
// code flow runs and Firebase is never started.
//
// Project: dalabapay-sms (Android app com.dalabapay.newproject).
// To change them, take the values from Firebase console → Project settings →
// Your apps (or from android/app/google-services.json):
//   apiKey      ← "current_key"           (client → api_key)
//   androidAppId← "mobilesdk_app_id"      (client → client_info)
//   senderId    ← "project_number"        (project_info)
//   projectId   ← "project_id"            (project_info)
// They are not secret. Each can also be given at build time, e.g.
//   flutter run --dart-define=FIREBASE_API_KEY=...
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'api/api.dart';

class FirebaseSetup {
  FirebaseSetup._();

  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyAKWLXo5Y2LjjYX9sy1eeQxftiGubDWlzI');
  static const String androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '1:128477486698:android:ea21ec30876d16b367f413');
  static const String iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');
  static const String senderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '128477486698');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'dalabapay-sms');
  static const String iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.dalabapay.newproject');

  static String get _appId =>
      defaultTargetPlatform == TargetPlatform.iOS ? iosAppId : androidAppId;

  static bool get configured =>
      apiKey.isNotEmpty && _appId.isNotEmpty && senderId.isNotEmpty && projectId.isNotEmpty;

  /// Starts Firebase once. Throws an [ApiException] the screens can show
  /// when this build has no Firebase settings.
  static Future<void> ensure() async {
    if (Firebase.apps.isNotEmpty) return;
    if (!configured) {
      throw const ApiException(0, 'SMS_NOT_CONFIGURED',
          'SMS verification isn\'t set up in this version of the app. Please update the app or contact support.');
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: _appId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: defaultTargetPlatform == TargetPlatform.iOS ? iosBundleId : null,
      ),
    );
  }
}

/// Sends the 6-digit SMS code with Firebase and turns the code the person
/// types into a Firebase ID token for the server to check.
class SmsVerification {
  String? _verificationId;
  int? _resendToken;

  /// Sends (or re-sends) the code to [phoneE164] (+234… / +232…).
  /// [onAutoVerified] fires on Android when the code is read automatically.
  Future<void> send(
    String phoneE164, {
    required VoidCallback onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(String message) onError,
  }) async {
    await FirebaseSetup.ensure();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        try {
          onAutoVerified(await _tokenFor(credential));
        } catch (e) {
          onError(_message(e));
        }
      },
      verificationFailed: (e) => onError(_message(e)),
      codeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
  }

  /// The code the person typed → Firebase ID token.
  Future<String> confirm(String smsCode) async {
    final id = _verificationId;
    if (id == null) {
      throw const ApiException(0, 'SMS', 'Please wait for the code to arrive, or tap Resend code.');
    }
    try {
      return await _tokenFor(PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode));
    } catch (e) {
      throw ApiException(0, 'SMS', _message(e));
    }
  }

  Future<String> _tokenFor(PhoneAuthCredential credential) async {
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final token = await result.user?.getIdToken(true);
    if (token == null) throw const ApiException(0, 'SMS', 'We couldn\'t confirm your phone. Please try again.');
    return token;
  }

  /// The Firebase session is only needed to prove the phone once.
  static Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  static String _message(Object e) {
    if (e is ApiException) return e.message;
    if (e is FirebaseAuthException) {
      debugPrint('Firebase phone auth: ${e.code} ${e.message}');
      switch (e.code) {
        case 'invalid-verification-code':
          return 'That code isn\'t right. Please check the SMS and try again.';
        case 'session-expired':
        case 'code-expired':
          return 'This code has expired. Tap Resend code for a new one.';
        case 'invalid-phone-number':
          return 'This phone number isn\'t valid for SMS. Please check it.';
        case 'too-many-requests':
        case 'quota-exceeded':
          return 'Too many codes requested. Please wait a while and try again.';
        case 'network-request-failed':
          return 'Can\'t reach the SMS service. Check your internet connection.';
        case 'app-not-authorized':
        case 'missing-client-identifier':
        case 'invalid-app-credential':
          return 'This app isn\'t authorised for SMS yet (Firebase app settings). Please contact support.';
      }
      return e.message ?? 'We couldn\'t send the SMS code. Please try again.';
    }
    debugPrint('SMS verification error: $e');
    return 'We couldn\'t send the SMS code. Please try again.';
  }
}
