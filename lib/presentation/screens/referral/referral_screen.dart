// lib/presentation/screens/referral/referral_screen.dart
// Refer & earn — UI only, sample numbers.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../mock/mock_data.dart';
import '../../../ui/ui.dart';

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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
                children: [
                  const DPAppear(scaleFrom: 0.97, child: _EarningsCard()),
                  const SizedBox(height: 24),
                  const Text('Bonus Breakdown', style: DP.section),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: _BonusCard(
                          'Direct Referral',
                          1500,
                          DP.green,
                          Icons.person_add_alt_1,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _BonusCard(
                          'Indirect Referral',
                          160,
                          DP.amber,
                          Icons.people_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: _BonusCard(
                          'Welcome Bonus',
                          200,
                          DP.navyIcon,
                          Icons.card_giftcard,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _BonusCard(
                          'Commission',
                          1560.5,
                          DP.navyIcon,
                          Icons.monetization_on_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _codeCard(context),
                  const SizedBox(height: 24),
                  DPSectionHeader(
                    'Recent Referrals',
                    actionLabel: 'See All',
                    onAction: () =>
                        Navigator.pushNamed(context, '/commission'),
                  ),
                  DPCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        for (var i = 0; i < kMockReferrals.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: DP.borderSoft),
                          _referralRow(kMockReferrals[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _guideCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _codeCard(BuildContext context) {
    return DPCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Referral Code', style: DP.section),
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
                const Expanded(
                  child: Text(
                    MockUser.referralCode,
                    style: TextStyle(
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
                    Clipboard.setData(
                      const ClipboardData(text: MockUser.referralCode),
                    );
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
            onPressed: () =>
                dpSnack(context, 'Sharing isn\'t set up in this UI build'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share this code with friends. When they join and make their first deposit (₦5000+), you both earn ₦200!',
            style: DP.caption,
          ),
        ],
      ),
    );
  }

  Widget _referralRow(MockReferral r) {
    return DPListRow(
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: DPAvatar(name: r.name, size: 40),
      title: r.name,
      subtitle:
          'Joined ${mockTimeAgo(DateTime.now().subtract(r.joined))} · ${r.active ? 'Active' : 'No deposit yet'}',
      trailing: Text(
        r.earned > 0 ? '+${DP.naira(r.earned, decimals: false)}' : 'Pending',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: r.earned > 0 ? DP.green : DP.amber,
        ),
      ),
    );
  }

  Widget _guideCard() {
    const steps = [
      'Share your referral code with friends',
      'They sign up and make first deposit (₦5000+)',
      'You both earn ₦200 instantly',
      'Earn ₦20 when your referrals invite others',
    ];
    return DPCard(
      color: DP.blueTint,
      borderColor: null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
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
          const Text(
            'All bonuses are credited to your commission balance and can be used for payments or withdrawn.',
            style: DP.caption,
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard();

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
            value: 1860,
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
              stat('Total Referrals', '${MockUser.referrals}',
                  Icons.people_outline),
              sep(),
              stat('Tier', 'Bronze', Icons.emoji_events_outlined),
              sep(),
              stat('Pending', '₦400.00', Icons.pending_actions),
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
