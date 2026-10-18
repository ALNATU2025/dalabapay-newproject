// lib/presentation/screens/referral/referral_screen.dart
// Refer & earn: GET /api/referrals (code, totals, tier, breakdown and the
// people you referred).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DPLogoBar(),
            Expanded(
              child: AsyncView<Map<String, dynamic>>(
                load: () async => asMap(await api.get('/api/referrals')),
                builder: (context, d, reload) => _body(context, d, reload),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> d,
      Future<void> Function() reload) {
    final b = asMap(d['breakdown']);
    final referrals = asList(d['referrals']);
    return RefreshIndicator(
              color: DP.green,
              onRefresh: reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
                children: [
                  DPAppear(scaleFrom: 0.97, child: _EarningsCard(d)),
                  const SizedBox(height: 24),
                  Text('Bonus Breakdown', style: DP.section),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BonusCard(
                          'Direct Referral',
                          toDouble(b['direct']),
                          DP.green,
                          Icons.person_add_alt_1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BonusCard(
                          'Indirect Referral',
                          toDouble(b['indirect']),
                          DP.amber,
                          Icons.people_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BonusCard(
                          'Welcome Bonus',
                          toDouble(b['welcome']),
                          DP.navyIcon,
                          Icons.card_giftcard,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BonusCard(
                          'Commission',
                          toDouble(b['commission']),
                          DP.navyIcon,
                          Icons.monetization_on_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _codeCard(context, d),
                  const SizedBox(height: 24),
                  DPSectionHeader(
                    'Recent Referrals',
                    actionLabel: 'See All',
                    onAction: () =>
                        Navigator.pushNamed(context, '/commission'),
                  ),
                  DPCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: referrals.isEmpty
                        ? const DPEmptyState(
                            icon: DPIcons.referral,
                            title: 'No referrals yet',
                            message: 'Share your code to start earning.',
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < referrals.length && i < 20; i++) ...[
                                if (i > 0)
                                  Divider(height: 1, color: DP.borderSoft),
                                _referralRow(referrals[i]),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                  _guideCard(d),
                ],
              ),
    );
  }

  Widget _codeCard(BuildContext context, Map<String, dynamic> d) {
    final code = str(d['code']);
    final bonus = DP.naira(toDouble(d['bonus']), decimals: false);
    final minDeposit = DP.naira(toDouble(d['minFirstDeposit']), decimals: false);
    return DPCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Referral Code', style: DP.section),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: DP.mint,
              borderRadius: BorderRadius.circular(DP.rMd),
              border: Border.all(color: DP.mintLine),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: DP.greenDeep,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  icon: const Icon(DPIcons.copy, color: DP.green),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    dpSnack(
                      context,
                      'Referral code copied to clipboard!',
                      success: true,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DPButton(
            label: 'Share code',
            icon: DPIcons.share,
            onPressed: () => Share.share(
              'Join me on Dalabapay — pay bills, buy airtime and earn commission. Use my referral code $code when you sign up and we both get $bonus after your first deposit of $minDeposit.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Share this code with friends. When they join and make their first deposit ($minDeposit+), you both earn $bonus!',
            style: DP.caption,
          ),
        ],
      ),
    );
  }

  Widget _referralRow(Map<String, dynamic> r) {
    final name = str(r['name']);
    final earned = toDouble(r['earned']);
    final active = r['active'] == true;
    return DPListRow(
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: DPAvatar(name: name, size: 40),
      title: name,
      subtitle:
          'Joined ${timeAgo(parseDate(r['joinedAt']))} · ${active ? 'Active' : 'No deposit yet'}',
      trailing: Text(
        earned > 0 ? '+${DP.naira(earned, decimals: false)}' : 'Pending',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: earned > 0 ? DP.green : DP.amber,
        ),
      ),
    );
  }

  Widget _guideCard(Map<String, dynamic> d) {
    final bonus = DP.naira(toDouble(d['bonus']), decimals: false);
    final indirect = DP.naira(toDouble(d['indirectBonus']), decimals: false);
    final minDeposit = DP.naira(toDouble(d['minFirstDeposit']), decimals: false);
    final steps = [
      'Share your referral code with friends',
      'They sign up and make first deposit ($minDeposit+)',
      'You both earn $bonus instantly',
      'Earn $indirect when your referrals invite others',
    ];
    return DPCard(
      color: DP.blueTint,
      borderColor: null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: DP.navyIcon),
              SizedBox(width: 8),
              Text('How to Earn More', style: DP.section),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: DP.navyIcon,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i], style: DP.body)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'All bonuses are credited to your commission balance and can be used for payments or withdrawn.',
            style: DP.caption,
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final Map<String, dynamic> d;
  const _EarningsCard(this.d);

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, IconData icon) => Column(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        );
    Widget sep() => Container(
          width: 1,
          height: 40,
          color: Colors.white.withValues(alpha: 0.3),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF35C08E), Color(0xFF15368A)],
          stops: [0.06, 0.41],
        ),
        borderRadius: BorderRadius.circular(DP.rXl),
        boxShadow: [
          BoxShadow(
            color: DP.green.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Referral Earnings',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          DPCountUp(
            value: toDouble(d['totalEarned']),
            format: (v) => DP.naira(v),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              stat('Total Referrals', '${toInt(d['totalReferrals'])}',
                  Icons.people_outline),
              sep(),
              stat('Tier', str(d['tier'], 'Bronze'), Icons.emoji_events_outlined),
              sep(),
              stat('Pending', DP.naira(toDouble(d['pendingEarnings'])),
                  Icons.pending_actions),
            ],
          ),
        ],
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  const _BonusCard(this.title, this.amount, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DP.rMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            DP.naira(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: DP.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
