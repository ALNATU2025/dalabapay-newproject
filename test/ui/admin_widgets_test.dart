// The redesigned admin building blocks render without overflow on a phone
// and on a wide screen (header, animated stat cards, pills, chart, list).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/screens/admin/admin_widgets.dart';
import 'package:dalabapay/ui/ui.dart';

import 'screenshot_helpers.dart';

Widget _page() => AdminScaffold(
      title: 'Admin Dashboard',
      breadcrumb: 'Admin / Dashboard',
      actions: [DPIconSquare(icon: DPIcons.bell, size: 40, background: Colors.transparent, onTap: () {})],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AdminStatGrid(stats: [
            AdminStat(label: 'Revenue', value: '₦1,250,500', icon: Icons.payments_outlined, color: DP.green, sub: '+12.5%'),
            AdminStat(label: 'Total Users', value: '2,431', icon: Icons.group_outlined, sub: '+38'),
            AdminStat(label: 'Sales Volume', value: '₦18,420,000', icon: Icons.receipt_long_outlined, color: DP.navyInk, sub: '-3%'),
            AdminStat(label: 'Pending', value: '7', icon: DPIcons.pending, color: DP.amber),
          ]),
          const SizedBox(height: 16),
          AdminBarChart(values: const [3, 5, 2, 8, 6, 9, 12], format: (v) => '$v'),
          const SizedBox(height: 16),
          const AdminListCard(children: [
            ListTile(title: Text('Foday Kamara'), trailing: StatusPill('Pending')),
            ListTile(title: Text('Ada Obi'), trailing: StatusPill('Successful')),
            ListTile(title: Text('Musa Bello'), trailing: StatusPill('Failed')),
          ]),
        ],
      ),
    );

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => DP.isDark = false);

  for (final dark in [false, true]) {
    testWidgets('admin page (phone${dark ? ', dark' : ''})', (tester) async {
      await snap(tester, 'admin_page_phone', _page, dark: dark);
      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('₦1,250,500'), findsOneWidget); // count-up finished
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('admin page (wide)', (tester) async {
    await snap(tester, 'admin_page_wide', _page, size: const Size(1280, 860));
    expect(find.text('2,431'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('count-up keeps the format', () {
    expect(AdminCountUp('₦1,250.50', style: const TextStyle()).text, '₦1,250.50');
  });
}
