// lib/presentation/screens/admin/admin_fund_wallet_page.dart
// Fund Wallet — UI only. Find a user and credit their wallet.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
import 'admin_mock.dart';
import 'admin_widgets.dart';

class AdminFundWalletPage extends StatefulWidget {
  const AdminFundWalletPage({super.key});

  @override
  State<AdminFundWalletPage> createState() => _AdminFundWalletPageState();
}

class _AdminFundWalletPageState extends State<AdminFundWalletPage> {
  String _query = '';
  String _filter = 'All';
  static const _filters = ['All', 'Active', 'Low Balance', 'Admins'];

  void _fund(AdminUser u) {
    final amount = TextEditingController();
    final note = TextEditingController();
    showAdminSheet(
      context,
      title: 'Fund Wallet',
      builder: (ctx, setSheet) {
        final a = double.tryParse(amount.text) ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DPAvatar(name: u.name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: DP.bodyStrong),
                      Text('Current Balance ${DP.naira(u.balance)}',
                          style: DP.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const DPLabel('Funding Amount'),
            DPField(
              controller: amount,
              hint: 'Enter amount (e.g., 1000.00)',
              prefixText: '₦  ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setSheet(() {}),
            ),
            const SizedBox(height: 10),
            const Text('Quick Amounts', style: DP.caption),
            const SizedBox(height: 6),
            QuickAmounts(controller: amount, onChanged: () => setSheet(() {})),
            const SizedBox(height: 14),
            const DPLabel('Note (Optional)'),
            DPField(
              controller: note,
              hint: 'Add a note for this transaction...',
            ),
            const SizedBox(height: 14),
            DPCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: DPSummaryRow('New Balance', DP.naira(u.balance + a),
                  strong: true),
            ),
            const SizedBox(height: 18),
            DPButton(
              label: 'Confirm Funding',
              onPressed: a <= 0
                  ? null
                  : () {
                      setState(() => u.balance += a);
                      Navigator.pop(ctx);
                      dpSnack(context, 'Funded ${DP.naira(a)} · ${u.name}',
                          success: true);
                    },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final users = kAdminUsers.where((u) {
      final f = switch (_filter) {
        'Active' => u.active,
        'Low Balance' => u.balance < 5000,
        'Admins' => u.isAdmin,
        _ => true,
      };
      return f &&
          (q.isEmpty ||
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.phone.contains(q));
    }).toList();
    final totalWallet = kAdminUsers.fold<double>(0, (a, u) => a + u.balance);
    final totalCommission =
        kAdminUsers.fold<double>(0, (a, u) => a + u.commission);

    return AdminScaffold(
      title: 'Fund Wallet',
      breadcrumb: 'Admin / Fund Wallet',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          AdminStatGrid(
            stats: [
              AdminStat(
                label: 'Total Wallet',
                value: DP.naira(totalWallet, decimals: false),
                icon: DPIcons.wallet,
                color: DP.green,
              ),
              AdminStat(
                label: 'Total Commission',
                value: DP.naira(totalCommission, decimals: false),
                icon: DPIcons.sparkle,
                color: DP.amber,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSearch(
            hint: 'Search by name, email or phone...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          DPChipScroller(
            options: _filters,
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 14),
          if (users.isEmpty)
            const DPEmptyState(
              icon: Icons.group_outlined,
              title: 'No Users Found',
              message: 'Try adjusting your search or filters',
            )
          else
            AdminListCard(
              children: [
                for (final u in users)
                  AdminUserRow(
                    name: u.name,
                    subtitle: '${u.email} · ${DP.naira(u.balance)}',
                    onTap: () => _fund(u),
                    trailing: SizedBox(
                      height: 34,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DP.green,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DP.rSm),
                          ),
                        ),
                        onPressed: () => _fund(u),
                        child: const Text('Fund'),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
