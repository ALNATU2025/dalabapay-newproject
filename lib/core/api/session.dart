// lib/core/api/session.dart
// The logged-in user. Screens listen to [Session.instance] so balances and
// names update everywhere after a payment or profile change.
import 'package:flutter/foundation.dart';

import '../../ui/dp_tokens.dart';
import 'dart:async';

import '../push.dart';
import 'api.dart';

class AppUser {
  final Map<String, dynamic> json;
  AppUser(this.json);

  String get id => json['id']?.toString() ?? '';
  String get fullName => json['fullName']?.toString() ?? '';
  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }

  String get email => json['email']?.toString() ?? '';
  String get phone => json['phone']?.toString() ?? '';
  String get role => json['role']?.toString() ?? 'user';
  bool get isAdmin => json['isAdmin'] == true;
  bool get isApproved => json['isApproved'] != false;
  bool get pinSet => json['pinSet'] == true;
  bool get pinLocked => json['pinLocked'] == true;
  double get balance => num.tryParse('${json['balance']}')?.toDouble() ?? 0;
  double get commissionBalance =>
      num.tryParse('${json['commissionBalance']}')?.toDouble() ?? 0;
  String get referralCode => json['referralCode']?.toString() ?? '';

  /// Sierra Leone account level (1–4); 0 for other countries.
  int get tier => num.tryParse('${json['tier']}')?.toInt() ?? 0;

  /// Why an admin turned the account down, if they did.
  String? get approvalNote {
    final v = json['approvalNote']?.toString();
    return v == null || v.isEmpty ? null : v;
  }

  /// "NG" or "SL". Decides services, dashboard and currency.
  String get country => json['country']?.toString() ?? 'NG';
  bool get isSierraLeone => country == 'SL';
  String get currency => json['currency']?.toString() ?? (isSierraLeone ? 'SLE' : 'NGN');
  List<String> get permissions =>
      (json['permissions'] as List? ?? const []).map((e) => '$e').toList();
  bool can(String permission) => permissions.contains(permission);

  Map<String, dynamic> get kyc =>
      (json['kyc'] as Map?)?.cast<String, dynamic>() ?? const {};
  String get kycStatus => kyc['status']?.toString() ?? 'none';

  /// Permanent bank account for transfers (after KYC), or null.
  Map<String, dynamic>? get dedicatedAccount =>
      (json['dedicatedAccount'] as Map?)?.cast<String, dynamic>();

  bool get biometricEnabled =>
      (json['preferences'] as Map?)?['biometricEnabled'] == true;
  bool get pushEnabled => (json['preferences'] as Map?)?['pushEnabled'] != false;
}

class Session extends ValueNotifier<AppUser?> {
  Session._() : super(null);
  static final Session instance = Session._();

  /// Keeps money formatting (DP.naira) in the signed-in user's currency.
  @override
  set value(AppUser? u) {
    DP.currency = u?.currency ?? 'NGN';
    super.value = u;
  }

  /// True for Sierra Leone accounts.
  bool get isSierraLeone => value?.isSierraLeone ?? false;

  /// Unread notifications for the bell badge.
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  AppUser? get user => value;
  bool get loggedIn => value != null && api.hasToken;

  /// On app start: loads the saved token and the profile. Returns true when
  /// the user is still logged in.
  Future<bool> restore() async {
    await api.loadToken();
    if (!api.hasToken) return false;
    try {
      await refresh();
      unawaited(PushNotifications.register());
      return true;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) await api.clearToken();
      // Offline: keep the token so the next attempt can succeed.
      return false;
    }
  }

  /// Saves the `{ token, user }` returned by login / sign-up.
  Future<void> start(Map<String, dynamic> data, {bool remember = true}) async {
    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await api.setToken(token, persist: remember);
    }
    final u = data['user'];
    if (u is Map) value = AppUser(u.cast<String, dynamic>());
    if (api.hasToken) unawaited(PushNotifications.register());
  }

  Future<AppUser?> refresh() async {
    final data = await api.get('/api/me');
    if (data is Map) value = AppUser(data.cast<String, dynamic>());
    return value;
  }

  /// Refresh without throwing (after payments etc.).
  Future<void> refreshQuietly() async {
    try {
      await refresh();
    } catch (_) {}
  }

  void setUser(Map<String, dynamic> json) => value = AppUser(json);

  /// Where to go after logging in: PIN setup first if there's no PIN yet.
  String get homeRoute => (value?.pinSet ?? false) ? '/dashboard' : '/pin-setup';

  Future<void> logout() async {
    await PushNotifications.unregister();
    await api.clearToken();
    value = null;
    unread.value = 0;
  }
}
