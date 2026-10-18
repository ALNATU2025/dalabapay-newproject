// End-to-end contract test: runs the app's API client against a real
// backend (newproject-backend + MongoDB) and checks that every request the
// screens send is accepted and every field the screens read is present.
//
// Runs only when API_URL is given (CI starts the backend first):
//   flutter test test/api_contract_test.dart --dart-define=API_URL=http://localhost:4000
// Set BACKEND_DIR (env) to the backend checkout so the test can promote a
// user to Super Admin with its script.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/core/api/api.dart';
import 'package:dalabapay/core/api/session.dart';
import 'package:dalabapay/core/format.dart';
import 'package:dalabapay/presentation/screens/admin/admin_models.dart';

const _hasServer = bool.hasEnvironment('API_URL');

int _n = 0;

/// 8 digits, unique per call within a run.
String _uniq() {
  final t = (DateTime.now().millisecondsSinceEpoch ~/ 10) % 10000000;
  return '${t.toString().padLeft(7, '0')}${_n++ % 10}';
}

/// Sign-up exactly as RegisterScreen does. Returns {token, user, email, phone}.
Future<Map<String, dynamic>> _signUp(String name, {String referral = ''}) async {
  final id = _uniq();
  final email = 'c$id@example.com';
  final phone = '080$id';
  final r = asMap(await api.post('/api/auth/register', {
    'fullName': name,
    'email': email,
    'phone': phone,
    'password': 'Passw0rdOk',
    'referralCode': referral,
  }));
  expect(r['devCode'], isNotNull, reason: 'backend must run without SMTP in CI');
  final data = asMap(await api.post('/api/auth/register/verify', {
    'email': email,
    'code': r['devCode'],
  }));
  await Session.instance.start(data);
  return {...data, 'email': email, 'phone': phone};
}

Map<String, dynamic> _txn(dynamic r) => asMap(asMap(r)['transaction']);

void _expectTxn(Map<String, dynamic> t) {
  for (final k in ['id', 'reference', 'type', 'status', 'amount', 'fee', 'commission', 'createdAt', 'direction', 'metadata']) {
    expect(t.containsKey(k), isTrue, reason: 'transaction.$k');
  }
}

void main() {
  if (!_hasServer) {
    test('contract test skipped (no API_URL)', () {});
    return;
  }

  late Map<String, dynamic> me;
  late Map<String, dynamic> friend;
  const pin = '246813';

  test('auth: sign up, login, PIN, password reset', () async {
    friend = await _signUp('Chidi Eze');
    me = await _signUp('Adaeze Okafor', referral: str(asMap(friend['user'])['referralCode']));
    expect(Session.instance.user!.firstName, 'Adaeze');
    expect(Session.instance.homeRoute, '/pin-setup');

    // LoginScreen
    final login = asMap(await api.post('/api/auth/login', {
      'identifier': me['phone'],
      'password': 'Passw0rdOk',
    }));
    await Session.instance.start(login);

    // Wrong password message is shown as-is
    try {
      await api.post('/api/auth/login', {'identifier': me['email'], 'password': 'nope'});
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.status, 401);
      expect(e.message, contains('Incorrect'));
    }
    // Session survived the failed login (401 with INVALID_CREDENTIALS)
    expect(api.hasToken, isTrue);

    // PinSetupScreen
    await api.post('/api/auth/pin/set', {'pin': pin});
    await Session.instance.refresh();
    expect(Session.instance.user!.pinSet, isTrue);
    expect(Session.instance.homeRoute, '/dashboard');
    // PinUnlock
    expect(asMap(await api.post('/api/auth/pin/verify', {'pin': pin}))['valid'], true);

    // ChangePinScreen forgot flow: forgot → code → reset
    final f = asMap(await api.post('/api/auth/pin/forgot'));
    await api.post('/api/auth/pin/reset', {'code': f['devCode'], 'newPin': '975310'});
    await api.post('/api/auth/pin/change', {'currentPin': '975310', 'newPin': pin});

    // ForgotPassword → OTP → Reset
    final fp = asMap(await api.post('/api/auth/password/forgot', {'email': me['email']}));
    final v = asMap(await api.post('/api/auth/password/verify-code', {
      'email': me['email'],
      'code': fp['devCode'],
    }));
    expect(str(v['resetToken']).length, greaterThan(10));
    await api.post('/api/auth/password/reset', {'resetToken': v['resetToken'], 'password': 'NewPassw0rd1'});
    // Old session is invalid now → log in again (LoginScreen)
    await Session.instance.start(asMap(await api.post('/api/auth/login', {
      'identifier': me['email'],
      'password': 'NewPassw0rd1',
    })));
    // ChangePasswordScreen returns a fresh token
    await Session.instance.start(asMap(await api.post('/api/auth/password/change', {
      'currentPassword': 'NewPassw0rd1',
      'newPassword': 'Passw0rdOk2',
    })));
    expect((await Session.instance.refresh())!.email, me['email']);
  });

  test('home, wallet, add money, send money', () async {
    // DashboardScreen
    final home = asMap(await api.get('/api/me/home'));
    expect(home['user'], isA<Map>());
    expect(home['recentTransactions'], isA<List>());
    expect(home.containsKey('unreadNotifications'), isTrue);
    expect(home.containsKey('maintenance'), isTrue);

    // WalletTopUpScreen
    final w = asMap(await api.get('/api/wallet'));
    for (final k in ['fundingFeePercent', 'minFunding', 'maxFunding', 'dedicatedAccount', 'balance']) {
      expect(w.containsKey(k), isTrue, reason: 'wallet.$k');
    }
    // Test-mode transfer (wallet screen debug button)
    await api.post('/api/dev/simulate-transfer', {'amount': 50000});
    await Session.instance.refresh();
    expect(Session.instance.user!.balance, greaterThan(40000));

    // One-time account dialog
    final ot = asMap(await api.post('/api/wallet/fund/one-time', {'amount': 2000, 'pin': pin}));
    final acct = asMap(ot['account']);
    for (final k in ['bankName', 'accountNumber', 'accountName', 'amountToPay', 'fee', 'youReceive', 'reference', 'expiresAt']) {
      expect(acct.containsKey(k), isTrue, reason: 'account.$k');
    }
    // "I've sent the money"
    final check = asMap(await api.post('/api/wallet/verify-payment', {'reference': acct['reference']}));
    expect(check['status'], 'pending');
    await api.post('/api/dev/simulate-transfer', {'amount': acct['amountToPay'], 'reference': acct['reference']});
    expect(asMap(await api.post('/api/wallet/verify-payment', {'reference': acct['reference']}))['status'], 'success');

    // Assisted
    final as = _txn(await api.post('/api/wallet/fund/assisted', {'amount': 1500, 'pin': pin}));
    expect(as['status'], 'pending');

    // TransactionValidationPage
    final fundings = asMap(await api.get('/api/wallet/fundings'));
    expect(itemsOf(fundings), isNotEmpty);
    expect(fundings.containsKey('verified'), isTrue);
    expect(fundings.containsKey('pending'), isTrue);

    // SendMoneyScreen
    final look = asMap(await api.post('/api/wallet/transfer/lookup', {'phone': friend['phone']}));
    expect(look['fullName'], 'Chidi Eze');
    final emailLook = asMap(await api.post('/api/wallet/transfer/lookup', {'email': friend['email']}));
    expect(emailLook['fullName'], 'Chidi Eze');
    final t = _txn(await api.post('/api/wallet/transfer', {
      'phone': friend['phone'],
      'amount': 1000,
      'note': 'Lunch',
      'pin': pin,
    }));
    _expectTxn(t);
    expect(t['status'], 'success');
  });

  test('bill payments exactly as the screens send them', () async {
    // Shared lookups (Catalog / CommissionRates)
    final nets = asList(await api.get('/api/services/networks'));
    expect(nets.first.keys, containsAll(['id', 'name']));
    final limits = asMap(await api.get('/api/services/limits'));
    expect(asMap(limits['airtime']).keys, containsAll(['minimum', 'perTxn', 'daily']));
    final rates = asMap(await api.get('/api/services/rates'));
    expect(rates['airtime'], isA<num>());

    // AirtimeScreen
    final air = _txn(await api.post('/api/services/airtime', {
      'network': 'mtn',
      'phone': '08031234567',
      'amount': 1000.0,
      'pin': pin,
    }));
    _expectTxn(air);
    expect(air['status'], 'success');
    expect(toDouble(air['commission']), greaterThan(0));
    // Recent recipients chips
    final recent = itemsOf(await api.get('/api/transactions',
        query: {'type': 'airtime', 'status': 'success', 'limit': 30}));
    expect(asMap(recent.first['metadata'])['network'], 'MTN');
    expect(recent.first['recipient'], '08031234567');

    // Failed purchase → refunded panel
    final failed = _txn(await api.post('/api/services/airtime', {
      'network': 'mtn', 'phone': '08030000000', 'amount': 200.0, 'pin': pin,
    }));
    expect(failed['status'], 'failed');
    expect(failed['refunded'], true);
    expect(asMap(failed['metadata'])['failureReason'], isNotNull);

    // Wrong PIN → message shown under the PIN boxes
    try {
      await api.post('/api/services/airtime', {'network': 'glo', 'phone': '08051112223', 'amount': 100.0, 'pin': '000001'});
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.code, 'PIN_INVALID');
    }

    // InternetScreen
    final plans = asList(await api.get('/api/services/data/plans', query: {'network': 'airtel'}));
    expect(plans.first.keys, containsAll(['code', 'name', 'amount', 'validity']));
    final data = _txn(await api.post('/api/services/data', {
      'network': 'airtel', 'phone': '08123456789', 'planCode': plans[1]['code'], 'pin': pin,
    }));
    expect(data['amount'], plans[1]['amount']);
    expect(asMap(data['metadata'])['plan'], isNotNull);

    // ElectricityScreen
    final discos = asList(await api.get('/api/services/electricity/providers'));
    expect(discos.first.keys, containsAll(['id', 'name', 'shortName']));
    final meter = asMap(await api.post('/api/services/electricity/verify', {
      'provider': discos.first['id'], 'meterNumber': '45031234567', 'meterType': 'prepaid',
    }));
    expect(meter['customerName'], isNotNull);
    expect(meter.containsKey('address'), isTrue);
    final elec = _txn(await api.post('/api/services/electricity', {
      'provider': discos.first['id'], 'meterNumber': '45031234567', 'meterType': 'prepaid',
      'amount': 2500.0, 'phone': '08031234567', 'pin': pin,
    }));
    expect(asMap(elec['metadata'])['token'], isNotNull);
    expect(asMap(elec['metadata'])['units'], isNotNull);

    // CableTvScreen
    final providers = asList(await api.get('/api/services/cable/providers'));
    final gotv = providers.firstWhere((p) => p['name'] == 'GOtv');
    final cablePlans = asList(await api.get('/api/services/cable/plans', query: {'provider': gotv['id']}));
    expect(cablePlans.first.keys, containsAll(['code', 'name', 'amount']));
    final card = asMap(await api.post('/api/services/cable/verify', {
      'provider': gotv['id'], 'smartcardNumber': '7023456789',
    }));
    for (final k in ['customerName', 'currentPlan', 'currentPlanCode', 'renewalAmount', 'dueDate']) {
      expect(card.containsKey(k), isTrue, reason: 'smartcard.$k');
    }
    final renew = _txn(await api.post('/api/services/cable', {
      'provider': gotv['id'], 'smartcardNumber': '7023456789', 'action': 'renew',
      'months': 2, 'phone': '08031234567', 'pin': pin,
    }));
    expect(toDouble(renew['amount']), toDouble(card['renewalAmount']) * 2);
    final change = _txn(await api.post('/api/services/cable', {
      'provider': gotv['id'], 'smartcardNumber': '7023456788', 'action': 'change',
      'planCode': cablePlans.last['code'], 'months': 1, 'phone': '08031234567', 'pin': pin,
    }));
    expect(change['amount'], cablePlans.last['amount']);

    // EducationScreen
    final products = asList(await api.get('/api/services/education/products'));
    expect(products.first.keys, containsAll(['id', 'name', 'requiresProfile', 'allowQuantity', 'variations']));
    final waec = products.firstWhere((p) => p['allowQuantity'] == true);
    final edu = _txn(await api.post('/api/services/education', {
      'service': waec['id'], 'variationCode': asList(waec['variations']).first['code'],
      'quantity': 2, 'phone': '08031234567', 'pin': pin,
    }));
    final pins = asList(asMap(edu['metadata'])['pins']);
    expect(pins.first.keys, containsAll(['serial', 'pin']));
    final jamb = products.firstWhere((p) => p['requiresProfile'] == true);
    final prof = asMap(await api.post('/api/services/education/verify', {
      'service': jamb['id'], 'profileId': '1234567890',
      'variationCode': asList(jamb['variations']).first['code'],
    }));
    expect(prof['customerName'], isNotNull);
    await api.post('/api/services/education', {
      'service': jamb['id'], 'variationCode': asList(jamb['variations']).first['code'],
      'quantity': 1, 'phone': '08031234567', 'profileId': '1234567890', 'pin': pin,
    });

    // InsuranceScreen
    final opts = asMap(await api.get('/api/services/insurance/options'));
    for (final k in ['types', 'makes', 'colors', 'engineCapacities', 'states']) {
      expect(opts.containsKey(k), isTrue, reason: 'insurance.$k');
    }
    final make = asList(opts['makes']).first;
    final models = asList(await api.get('/api/services/insurance/models', query: {'make': make['id']}));
    expect(models.first['name'], isNotNull);
    final state = (opts['states'] as List).first;
    final lgas = await api.get('/api/services/insurance/lgas', query: {'state': state});
    expect(lgas, isA<List>());
    final ins = _txn(await api.post('/api/services/insurance', {
      'typeCode': asList(opts['types']).first['code'],
      'plateNumber': 'LAG123XY',
      'chassisNumber': 'JTDBR32E720123456',
      'yearOfMake': '2018',
      'make': make['name'],
      'model': models.first['name'],
      'color': (opts['colors'] as List).first,
      'engineCapacity': (opts['engineCapacities'] as List).first,
      'state': state,
      'lga': (lgas as List).first,
      'insuredName': 'Adaeze Okafor',
      'email': 'adaeze@example.com',
      'phone': '08031234567',
      'pin': pin,
    }));
    expect(asMap(ins['metadata'])['certificateNumber'], isNotNull);

    // InternationalAirtimeScreen
    final countries = asList(await api.get('/api/services/international/countries'));
    expect(countries.first.keys, containsAll(['code', 'name', 'flag', 'dialCode', 'currency']));
    final gh = countries.firstWhere((c) => c['code'] == 'GH');
    final types = asList(await api.get('/api/services/international/product-types', query: {'country': 'GH'}));
    final topup = types.firstWhere((t) => t['id'] == 'topup');
    final ops = asList(await api.get('/api/services/international/operators',
        query: {'country': 'GH', 'productType': topup['id']}));
    final vars = asMap(await api.get('/api/services/international/variations',
        query: {'country': 'GH', 'operator': ops.first['id'], 'productType': topup['id']}));
    expect(vars.keys, containsAll(['currency', 'rate', 'variations']));
    final v = asList(vars['variations']).first;
    expect(v.keys, containsAll(['code', 'name', 'fixed']));
    final intl = _txn(await api.post('/api/services/international', {
      'country': gh['code'], 'productType': topup['id'], 'operator': ops.first['id'],
      'variationCode': v['code'], 'phone': '241234567', 'amount': 10.0, 'pin': pin,
    }));
    expect(toDouble(intl['amount']), closeTo(10 * toDouble(vars['rate']), 0.01));
  });

  test('history, earnings, referrals, notifications, disputes, KYC', () async {
    // TransactionsScreen filters
    final all = asMap(await api.get('/api/transactions', query: {'page': 1, 'limit': 20}));
    expect(all.keys, containsAll(['items', 'hasMore', 'total']));
    final airtime = itemsOf(await api.get('/api/transactions', query: {'type': 'airtime,international'}));
    expect(airtime.every((t) => t['type'] == 'airtime' || t['type'] == 'international'), isTrue);
    final ok = itemsOf(await api.get('/api/transactions', query: {'status': 'success', 'q': 'MTN'}));
    expect(ok, isNotEmpty);
    final earn = itemsOf(await api.get('/api/transactions',
        query: {'type': 'commission,commission_withdrawal,referral_bonus', 'wallet': 'all'}));
    expect(earn, isNotEmpty);
    final today = isoDay(DateTime.now());
    final ranged = itemsOf(await api.get('/api/transactions', query: {'from': today, 'to': today}));
    expect(ranged, isNotEmpty);

    // CommissionScreen
    final c = asMap(await api.get('/api/commission'));
    for (final k in ['balance', 'lifetime', 'movedToWallet', 'minWithdrawal', 'week', 'recent']) {
      expect(c.containsKey(k), isTrue, reason: 'commission.$k');
    }
    expect(asList(c['week']), hasLength(7));
    expect(asList(c['week']).first.keys, containsAll(['date', 'amount']));

    // ReferralScreen (friend referred me; my first deposit was ₦50,000)
    await api.setToken(str(friend['token']));
    final ref = asMap(await api.get('/api/referrals'));
    for (final k in ['code', 'totalReferrals', 'tier', 'totalEarned', 'pendingEarnings', 'breakdown', 'bonus', 'indirectBonus', 'minFirstDeposit', 'referrals']) {
      expect(ref.containsKey(k), isTrue, reason: 'referrals.$k');
    }
    expect(asList(ref['referrals']).first.keys, containsAll(['name', 'joinedAt', 'active', 'earned']));
    expect(toInt(ref['totalReferrals']), 1);
    await api.setToken(str(me['token']));

    // NotificationsScreen
    final n = asMap(await api.get('/api/notifications', query: {'page': 1, 'limit': 30}));
    expect(n.keys, containsAll(['items', 'unread', 'hasMore']));
    final first = itemsOf(n).first;
    expect(first.keys, containsAll(['id', 'title', 'body', 'kind', 'read', 'createdAt']));
    await api.patch('/api/notifications/${first['id']}/read');
    await api.delete('/api/notifications/${first['id']}');
    expect(asMap(await api.post('/api/notifications/read-all'))['unread'], 0);

    // UserDisputesPage
    final eligible = asList(await api.get('/api/disputes/eligible'));
    expect(eligible, isNotEmpty);
    final d = asMap(await api.post('/api/disputes', {
      'transactionId': eligible.first['id'],
      'type': 'service_not_delivered',
      'reason': 'Not received',
      'description': 'Nothing arrived on the line',
    }));
    expect(asMap(d['transaction'])['reference'], isNotNull);
    final mine = asMap(await api.get('/api/disputes'));
    expect(itemsOf(mine).first.keys, containsAll(['id', 'type', 'reason', 'status', 'resolution', 'createdAt', 'transaction']));

    // Settings → push switch
    final prefs = asMap(await api.patch('/api/me/preferences', {'pushEnabled': false}));
    expect(asMap(prefs['preferences'])['pushEnabled'], false);

    // KYCScreen
    final k = asMap(await api.post('/api/kyc', {
      'bvn': '22212345678', 'dateOfBirth': '01/02/1995', 'gender': 'Female', 'address': '12 Admiralty Way, Lekki',
    }));
    expect(k['status'], 'verified');
    expect(asMap(k['dedicatedAccount']).keys, containsAll(['accountNumber', 'accountName', 'bankName']));
    await Session.instance.refresh();
    expect(Session.instance.user!.dedicatedAccount, isNotNull);
    expect(Session.instance.user!.kycStatus, 'verified');

    // Commission → wallet (min ₦500, so earn some first with a big airtime)
    await api.post('/api/dev/simulate-transfer', {'amount': 50000});
    await api.post('/api/services/airtime', {'network': 'glo', 'phone': '08057777777', 'amount': 30000.0, 'pin': pin});
    final w = _txn(await api.post('/api/commission/withdraw'));
    expect(w['type'], 'commission_withdrawal');
  });

  test('admin console endpoints as the admin pages call them', () async {
    final backend = Platform.environment['BACKEND_DIR'];
    if (backend == null) {
      markTestSkipped('BACKEND_DIR not set');
      return;
    }
    final promote = await Process.run(
      'node',
      ['scripts/make-super-admin.js', str(me['email'])],
      workingDirectory: backend,
    );
    expect(promote.exitCode, 0, reason: '${promote.stdout}\n${promote.stderr}');
    await Session.instance.refresh();
    expect(Session.instance.user!.isAdmin, isTrue);
    expect(adminCan('roles:manage'), isTrue);

    // AdminDashboardScreen
    final dash = asMap(await api.get('/api/admin/dashboard', query: {'period': 'week'}));
    for (final k in ['revenue', 'revenueChange', 'volume', 'volumeChange', 'totalUsers', 'newUsers', 'transactions', 'pending', 'volume7d', 'users7d', 'recentTransactions']) {
      expect(dash.containsKey(k), isTrue, reason: 'dashboard.$k');
    }
    AdminTxn.fromJson(asList(dash['recentTransactions']).first);
    final alertsHead = asMap(await api.get('/api/admin/alerts', query: {'limit': 1}));
    expect(alertsHead.containsKey('unread'), isTrue);

    // AdminUsersPage
    final users = asMap(await api.get('/api/admin/users', query: {'q': '', 'filter': 'all', 'page': 1}));
    expect(asMap(users['counts']).keys, containsAll(['all', 'active', 'admins', 'pending']));
    expect(asMap(users['totals']).keys, containsAll(['walletBalance', 'commissionBalance']));
    final friendRow = itemsOf(await api.get('/api/admin/users', query: {'q': friend['email']})).first;
    final fu = AdminUser.fromJson(friendRow);
    expect(fu.name, 'Chidi Eze');
    await api.post('/api/admin/users/${fu.id}/approve');
    final credited = asMap(await api.post('/api/admin/users/${fu.id}/wallet', {
      'action': 'credit', 'amount': 500.0, 'reason': 'Bonus / Goodwill', 'note': 'Thanks',
    }));
    expect(asMap(credited['user'])['balance'], isNotNull);
    await api.post('/api/admin/users/${fu.id}/wallet', {'action': 'credit', 'amount': 1000.0, 'reason': 'Manual Deposit'});
    await api.post('/api/admin/users/${fu.id}/wallet', {'action': 'debit', 'amount': 100.0, 'reason': 'Correcting overcharged amount'});

    // AdminEditUserPage
    final detail = asMap(await api.get('/api/admin/users/${fu.id}'));
    expect(detail.keys, containsAll(['pinLocked', 'pinSet', 'pinLockedUntil', 'balance', 'transactions']));
    await api.patch('/api/admin/users/${fu.id}', {'fullName': 'Chidi Eze Jr'});
    // AdminUserHistoryPage
    final hist = asMap(await api.get('/api/admin/users/${fu.id}/history'));
    expect(hist.keys, containsAll(['user', 'credits', 'debits', 'transactions', 'activity']));
    expect(asList(hist['activity']).first.keys, containsAll(['action', 'details', 'actor', 'createdAt']));

    // AdminAllTransactionsPage
    final list = asMap(await api.get('/api/admin/transactions', query: {
      'q': '', 'status': 'success', 'service': 'airtime', 'sort': 'highest', 'page': 1,
    }));
    expect(list.keys, containsAll(['items', 'total', 'totalAmount', 'counts', 'hasMore']));
    final at = AdminTxn.fromJson(itemsOf(list).first);
    expect(at.userName, isNot('—'));
    final csv = await api.getText('/api/admin/transactions/export.csv', query: {'status': 'success'});
    expect(csv.split('\n').first, startsWith('Date,Reference'));

    // AdminTransactionStatusPage: pending airtime → requery / failed
    final pending = _txn(await api.post('/api/services/airtime', {
      'network': 'mtn', 'phone': '08039999999', 'amount': 300.0, 'pin': pin,
    }));
    expect(pending['status'], 'pending');
    final rq = asMap(await api.post('/api/admin/transactions/${pending['id']}/requery'));
    expect(rq.keys, containsAll(['result', 'transaction']));
    // Approve the assisted top-up from earlier
    final assisted = itemsOf(await api.get('/api/admin/transactions',
        query: {'status': 'pending', 'service': 'wallet_funding'}));
    expect(assisted, isNotEmpty);
    await api.patch('/api/admin/transactions/${assisted.first['id']}/status', {
      'status': kStatusValues['Successful'], 'note': 'Cash received',
    });

    // AdminRefundSystemPage
    final disputes = asMap(await api.get('/api/admin/disputes', query: {'status': 'all'}));
    final ad = AdminDispute.fromJson(itemsOf(disputes).first);
    expect(ad.open, isTrue);
    final queue = asMap(await api.get('/api/admin/transactions/refund-queue'));
    expect(queue.keys, containsAll(['queue', 'refunded']));
    await api.post('/api/admin/disputes/${ad.id}/resolve', {'action': 'approve', 'resolution': 'Refunded after checking'});
    final p2 = _txn(await api.post('/api/services/airtime', {
      'network': 'mtn', 'phone': '08049999999', 'amount': 400.0, 'pin': pin,
    }));
    await api.post('/api/admin/transactions/${p2['id']}/refund', {'amount': 400.0, 'reason': 'Provider timeout'});

    // AdminSelfFundPage
    final sf = asMap(await api.get('/api/admin/payments/self-fund'));
    expect(sf.keys, containsAll(['balance', 'history']));
    final sfr = asMap(await api.post('/api/admin/payments/self-fund', {'amount': 5000.0, 'pin': pin}));
    expect(sfr['balance'], isNotNull);

    // AdminVerifyPaymentPage
    final stats = asMap(await api.get('/api/admin/payments/verify/stats'));
    expect(stats.keys, containsAll(['verifiedToday', 'amountToday']));
    final fundings = itemsOf(await api.get('/api/admin/transactions', query: {'service': 'wallet_funding'}));
    final vr = asMap(await api.post('/api/admin/payments/verify', {'reference': fundings.first['reference']}));
    expect(asMap(asMap(vr['transaction'])['user'])['fullName'], isNotNull);
    final man = asMap(await api.post('/api/admin/payments/manual', {
      'user': friend['email'], 'amount': 700.0, 'reference': 'BANKREF${_uniq()}', 'description': 'Unmatched transfer',
    }));
    expect(asMap(man['user'])['fullName'], isNotNull);

    // AdminSendNotificationPage
    final bc = asMap(await api.get('/api/admin/broadcasts'));
    expect(bc.keys, containsAll(['sent', 'broadcasts', 'activeUsers', 'recent']));
    final sent = asMap(await api.post('/api/admin/broadcasts', {
      'title': 'Weekend promo', 'message': 'Extra commission on data', 'type': 'promotional', 'audience': 'selected', 'userIds': [fu.id],
    }));
    expect(sent['sent'], 1);

    // AdminNotificationsPage
    final alerts = asMap(await api.get('/api/admin/alerts', query: {'type': 'new_user', 'page': 1}));
    final al = AdminAlert.fromJson(itemsOf(alerts).first);
    await api.patch('/api/admin/alerts/${al.id}/read');
    await api.post('/api/admin/alerts/read-all');

    // AdminControlPage
    final roles = asMap(await api.get('/api/admin/roles'));
    expect(roles.keys, containsAll(['admins', 'regularUsers', 'roles']));
    await api.post('/api/admin/roles', {'userId': fu.id, 'role': 'support'});
    await api.post('/api/admin/roles', {'userId': fu.id, 'role': 'user'});

    // VtpassSettingsDashboard
    final settings = asMap(await api.get('/api/admin/settings'));
    expect(settings.keys, containsAll(['services', 'serviceLabels', 'maintenance', 'maintenanceMessage', 'lowBalanceAlerts']));
    final prov = asMap(await api.get('/api/admin/provider'));
    expect(prov.keys, containsAll(['bill', 'payment', 'balance', 'lowBalance', 'lowBalanceThreshold']));
    final h = asMap(await api.post('/api/admin/provider/health'));
    expect(h.keys, containsAll(['ok', 'message', 'latencyMs', 'checkedAt']));
    final tc = asMap(await api.post('/api/admin/provider/test'));
    expect(tc.keys, containsAll(['ok', 'message']));
    await api.patch('/api/admin/settings', {'services': {'insurance': false}});
    await api.patch('/api/admin/settings', {'services': {'insurance': true}, 'maintenanceMessage': 'Back soon'});
    await api.patch('/api/admin/settings', {'lowBalanceAlerts': true});

    // AdminServiceCommissionPage
    final com = asMap(await api.get('/api/admin/commission', query: {'period': 'month'}));
    expect(com.keys, containsAll(['revenue', 'commissionPaid', 'volume', 'avgRevenuePerTxn', 'revenue7d', 'services']));
    expect(asList(com['services']).first.keys, containsAll(['service', 'label', 'rate', 'transactions', 'volume', 'revenue']));
    await api.patch('/api/admin/commission/rates/airtime', {'user': 2.0, 'platform': 1.0});

    // AdminTransactionLimitsPage
    final lim = asMap(await api.get('/api/admin/limits'));
    expect(lim.keys, containsAll(['defaults', 'labels', 'overrides']));
    final defs = asMap(await api.put('/api/admin/limits/defaults', {
      'airtime': {'perTxn': 50000.0, 'daily': 200000.0},
    }));
    expect(asMap(defs['airtime'])['perTxn'], 50000);
    final ul = asMap(await api.get('/api/admin/limits/users/${fu.id}'));
    expect(asMap(asMap(ul['limits'])['airtime']).keys, containsAll(['perTxn', 'daily', 'custom']));
    await api.put('/api/admin/limits/users/${fu.id}', {'data': {'perTxn': 1000.0, 'daily': null}});
    final withOverride = asMap(await api.get('/api/admin/limits'));
    expect(asList(withOverride['overrides']).first.keys, containsAll(['user', 'limits']));
    await api.put('/api/admin/limits/users/${fu.id}', {'data': null});

    // AdminEditUserPage PIN controls (friend never set a PIN → reset is a no-op path)
    await api.post('/api/admin/users/${fu.id}/pin/unlock');
  });

  test('logged-out requests are rejected and clear the session', () async {
    var called = false;
    api.onUnauthorized = () => called = true;
    await api.setToken('not-a-real-token');
    try {
      await api.get('/api/me');
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.status, 401);
    }
    expect(called, isTrue);
    expect(api.hasToken, isFalse);
  });
}
