// VTpass portal: overview dashboard and transactions list (sample data).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/admin/admin_vtpass_portal_page.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

final _summary = <String, dynamic>{
  'period': 'month',
  'currency': 'NGN',
  'commissionRate': 1.8,
  'provider': {'name': 'vtpass', 'environment': 'live', 'configured': true},
  'balance': 184250.75,
  'lowBalance': false,
  'lowBalanceThreshold': 50000,
  'counts': {'total': 412, 'success': 389, 'failed': 17, 'pending': 4, 'refunded': 2},
  'successRate': 95.8,
  'volume': 6842500,
  'averagePayment': 17590,
  'commission': {'earned': 123165, 'reportedByVtpass': 98400, 'reportedCount': 301, 'estimatedCount': 88, 'paidToUsers': 34212.5, 'net': 88952.5},
  'byService': [
    {'service': 'cable', 'label': 'DStv', 'count': 214, 'success': 203, 'volume': 4120000, 'earned': 74160},
    {'service': 'cable', 'label': 'GOtv', 'count': 151, 'success': 147, 'volume': 1985000, 'earned': 35730},
    {'service': 'cable', 'label': 'StarTimes', 'count': 31, 'success': 30, 'volume': 412500, 'earned': 7425},
    {'service': 'international', 'label': 'International airtime', 'count': 16, 'success': 9, 'volume': 325000, 'earned': 5850},
  ],
  'series': [
    for (var i = 0; i < 30; i++)
      {'date': '2026-${i < 6 ? '10' : '11'}-${(i < 6 ? 26 + i : i - 5).toString().padLeft(2, '0')}', 'volume': 120000.0 + (i * 37000) % 260000, 'earned': 2160.0 + (i * 666) % 4680, 'success': 10 + i % 7, 'failed': i % 4 == 0 ? 1 : 0},
  ],
  'seriesUnit': 'day',
  'topFailures': [
    {'reason': 'TRANSACTION FAILED', 'count': 9},
    {'reason': 'Invalid smartcard number', 'count': 5},
    {'reason': 'This service is temporarily unavailable.', 'count': 3},
  ],
};

final _txns = <String, dynamic>{
  'total': 412,
  'pages': 17,
  'totals': {'volume': 6842500, 'commission': 123165},
  'items': [
    {'id': '1', 'reference': '202611242140DP1', 'createdAt': '2026-11-24T20:40:00Z', 'service': 'cable', 'serviceLabel': 'DStv', 'description': 'DStv Compact', 'recipient': '7039216378', 'amount': 19000, 'status': 'success', 'user': {'fullName': 'Alusine Jalloh', 'phone': '09163207050', 'country': 'NG'}, 'vtpass': {'transactionId': '17324891233', 'code': '000'}, 'commission': 342, 'commissionReported': true},
    {'id': '2', 'reference': '202611242131DP2', 'createdAt': '2026-11-24T20:31:00Z', 'service': 'cable', 'serviceLabel': 'GOtv', 'description': 'GOtv Supa', 'recipient': '7020000001', 'amount': 11400, 'status': 'success', 'user': {'fullName': 'Fatmata Bangura', 'phone': '08031112222', 'country': 'NG'}, 'vtpass': {'transactionId': '17324889012'}, 'commission': 205.2, 'commissionReported': false},
    {'id': '3', 'reference': '202611242120DP3', 'createdAt': '2026-11-24T20:20:00Z', 'service': 'cable', 'serviceLabel': 'DStv', 'description': 'DStv Current package', 'recipient': '7039216378', 'amount': 19000, 'status': 'failed', 'refunded': true, 'user': {'fullName': 'Alusine Jalloh', 'phone': '09163207050', 'country': 'NG'}, 'vtpass': {'code': '016'}, 'commission': 0, 'failureReason': 'TRANSACTION FAILED'},
    {'id': '4', 'reference': '202611242101DP4', 'createdAt': '2026-11-24T20:01:00Z', 'service': 'international', 'serviceLabel': 'International airtime', 'description': 'Ghana · MTN airtime', 'recipient': '+233241234567', 'amount': 5000, 'status': 'pending', 'user': {'fullName': 'Ibrahim Conteh', 'phone': '076123456', 'country': 'SL'}, 'vtpass': {}, 'commission': 0},
  ],
};

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  for (final dark in [false, true]) {
    testWidgets('VTpass portal overview${dark ? ' (dark)' : ''}', (tester) async {
      await snap(tester, 'admin_vtpass_portal', () => AdminVtpassPortalPage(initialSummary: _summary, initialTransactions: _txns),
          size: const Size(400, 2300), dark: dark);
      expect(find.text('VTpass Portal'), findsOneWidget);
      expect(find.text('₦184,250.75'), findsOneWidget);
      expect(find.text('Commission statement'), findsOneWidget);
      expect(find.text('95.8%'), findsOneWidget);
      expect(find.text('TRANSACTION FAILED'), findsOneWidget);
    });
  }

  testWidgets('VTpass portal transactions', (tester) async {
    await snap(tester, 'admin_vtpass_transactions', () => AdminVtpassPortalPage(initialSummary: _summary, initialTransactions: _txns, initialTab: 1),
        size: const Size(400, 1100));
    expect(find.text('DStv Compact'), findsOneWidget);
    expect(find.textContaining('Code 016 · TRANSACTION FAILED'), findsOneWidget);
    expect(find.text('+₦205.20 est.'), findsOneWidget);
  });
}
