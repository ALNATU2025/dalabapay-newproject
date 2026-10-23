// lib/presentation/screens/cards/cards_screen.dart
// Virtual dollar cards (through Cashwyre). Paid for from the wallet in
// Naira or Leones; the card itself holds US dollars.
//   GET  /api/cards, /api/cards/config, /api/cards/quote
//   POST /api/cards/:id/topup | withdraw | reveal | freeze | unfreeze
//   GET  /api/cards/:id/transactions
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';
import '../../widgets/async_view.dart';
import '../../widgets/payment_flow.dart';
import '../../widgets/pin_sheet.dart';
import 'create_card_screen.dart';

String usd(num? v) => '\$${DP.moneyIn(v, 'NGN').replaceFirst('₦', '')}';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _cards = [];
  Map<String, dynamic> _config = {};
  int _index = 0;

  bool get _sl => Session.instance.isSierraLeone;
  String get _service => _sl ? 'sl_card' : 'card';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _cards.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait([api.get('/api/cards'), api.get('/api/cards/config')]);
      if (!mounted) return;
      setState(() {
        _cards = asList(results[0]);
        _config = asMap(results[1]);
        if (_index >= _cards.length) _index = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool get _available => _config['connected'] == true && _config['open'] != false;
  bool get _canAddCard =>
      _available && _cards.where((c) => c['status'] != 'terminated').length < toInt(_config['maxCards'] ?? 2);

  Future<void> _create() async {
    final made = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateCardScreen(config: _config)),
    );
    if (made == true) _load();
  }

  Future<double?> _askUsd(String title, String message, {double? max}) {
    final ctrl = TextEditingController();
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DPSheetHandle(),
                const SizedBox(height: 8),
                Text(title, style: DP.title),
                const SizedBox(height: 6),
                Text(message, style: DP.caption),
                const SizedBox(height: 18),
                const DPLabel('Amount in US dollars'),
                DPField(
                  controller: ctrl,
                  hint: '0.00',
                  prefixText: '\$ ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                ),
                if (max != null) DPHelper('You can move up to ${usd(max)}.'),
                const SizedBox(height: 18),
                DPButton(
                  label: 'Continue',
                  icon: DPIcons.forward,
                  onPressed: () {
                    final v = double.tryParse(ctrl.text) ?? 0;
                    if (v < 1) {
                      dpSnack(ctx, 'Enter at least \$1', error: true);
                      return;
                    }
                    if (max != null && v > max) {
                      dpSnack(ctx, 'That\'s more than you can move', error: true);
                      return;
                    }
                    Navigator.pop(ctx, v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _quote(String action, double amountUsd) async {
    try {
      return asMap(await api.get('/api/cards/quote', query: {'action': action, 'amountUsd': amountUsd}));
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
      return null;
    }
  }

  Future<void> _topUp(Map<String, dynamic> card) async {
    final amount = await _askUsd('Add money to card', 'Paid from your wallet. Cashwyre\'s top-up fee is ${toDouble(asMap(_config['fees'])['topupPercent'])}%.');
    if (amount == null || !mounted) return;
    final q = await _quote('topup', amount);
    if (q == null || !mounted) return;
    final local = toDouble(q['local']);
    await showReviewAndPay(
      context,
      icon: DPIcons.card,
      title: 'Top up card •••• ${str(card['last4'])}',
      serviceLabel: 'Dollar card top-up',
      amount: local,
      service: _service,
      rows: [
        DPReviewRow('Card', '${str(card['brand'])} •••• ${str(card['last4'])}'),
        DPReviewRow('Added to card', usd(amount)),
        DPReviewRow('Card fee', usd(toDouble(q['feeUsd']))),
        DPReviewRow('Rate', '\$1 = ${DP.naira(toDouble(q['rate']))}'),
        DPReviewRow('Total to pay', DP.naira(local), strong: true),
      ],
      successTitle: 'Card topped up',
      successSubtitle: '${usd(amount)} is on your card.',
      onPay: (pin) async {
        final r = await api.post('/api/cards/${card['id']}/topup', {'amountUsd': amount, 'pin': pin});
        return asMap(asMap(r)['transaction']);
      },
    );
    _load();
  }

  Future<void> _withdraw(Map<String, dynamic> card) async {
    final minLeft = toDouble(asMap(_config['fees'])['minimumLeftOnCardUsd'] ?? 1);
    final max = toDouble(card['balanceUsd']) - minLeft;
    if (max < 1) {
      dpSnack(context, 'There isn\'t enough on the card. ${usd(minLeft)} must stay on it.', error: true);
      return;
    }
    final amount = await _askUsd('Move to wallet', '${usd(minLeft)} must stay on the card.', max: max);
    if (amount == null || !mounted) return;
    final q = await _quote('withdraw', amount);
    if (q == null || !mounted) return;
    final pin = await askPin(
      context,
      title: 'Move ${usd(amount)} to your wallet',
      message: 'You\'ll receive about ${DP.naira(toDouble(q['local']))} (\$1 = ${DP.naira(toDouble(q['rate']))}).',
      confirmLabel: 'Move money',
    );
    if (pin == null || !mounted) return;
    try {
      final r = asMap(await api.post('/api/cards/${card['id']}/withdraw', {'amountUsd': amount, 'pin': pin}));
      final t = asMap(r['transaction']);
      if (!mounted) return;
      await Session.instance.refreshQuietly();
      if (!mounted) return;
      dpSnack(
        context,
        str(t['status']) == 'success'
            ? '${DP.naira(toDouble(t['amount']))} is now in your wallet.'
            : 'Processing. We\'ll credit your wallet once it\'s confirmed.',
        success: true,
      );
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
    _load();
  }

  Future<void> _reveal(Map<String, dynamic> card) async {
    final pin = await askPin(context, title: 'Show card details', message: 'Enter your PIN to see the full card number and CVV.');
    if (pin == null || !mounted) return;
    Map<String, dynamic> d;
    try {
      d = asMap(await api.post('/api/cards/${card['id']}/reveal', {'pin': pin}));
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    final billing = asMap(d['billing']);
    final number = str(d['number']).replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim();
    final address = [billing['street'], billing['city'], billing['zip'], billing['country']]
        .where((x) => x != null && '$x'.isNotEmpty)
        .join(', ');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DPSheetHandle(),
              const SizedBox(height: 8),
              Text('Card details', style: DP.title),
              const SizedBox(height: 4),
              Text('Don\'t share these with anyone.', style: DP.caption),
              const SizedBox(height: 12),
              _copyRow(ctx, 'Card number', number, str(d['number'])),
              _copyRow(ctx, 'Expiry', str(d['validMonthYear'])),
              _copyRow(ctx, 'CVV', str(d['cvv'])),
              _copyRow(ctx, 'Name on card', str(d['name'])),
              if (address.isNotEmpty) _copyRow(ctx, 'Billing address', address),
            ],
          ),
        ),
      ),
    );
  }

  Widget _copyRow(BuildContext ctx, String label, String value, [String? copyValue]) {
    return DPListRow(
      title: value.isEmpty ? '—' : value,
      subtitle: label,
      subtitleMaxLines: 1,
      trailing: value.isEmpty
          ? null
          : IconButton(
              tooltip: 'Copy $label',
              icon: Icon(DPIcons.copy, color: DP.muted, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyValue ?? value));
                dpSnack(ctx, '$label copied', success: true);
              },
            ),
    );
  }

  Future<void> _toggleFreeze(Map<String, dynamic> card) async {
    final frozen = card['status'] == 'frozen';
    final ok = await dpDialog(
      context,
      title: frozen ? 'Unfreeze card?' : 'Freeze card?',
      message: frozen
          ? 'Payments with this card will work again.'
          : 'All payments with this card will be blocked until you unfreeze it.',
      confirmLabel: frozen ? 'Unfreeze' : 'Freeze',
      cancelLabel: 'Cancel',
      tone: frozen ? DPTone.info : DPTone.warning,
    );
    if (ok != true || !mounted) return;
    try {
      await api.post('/api/cards/${card['id']}/${frozen ? 'unfreeze' : 'freeze'}');
      if (mounted) dpSnack(context, frozen ? 'Card unfrozen' : 'Card frozen', success: true);
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
    _load();
  }

  Future<void> _history(Map<String, dynamic> card) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DP.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _CardHistory(cardId: str(card['id']), scroll: scroll),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        child: Column(
          children: [
            DPTopBar(
              title: 'Dollar card',
              trailing: _canAddCard && _cards.isNotEmpty
                  ? IconButton(tooltip: 'New card', icon: Icon(DPIcons.plus, color: DP.ink), onPressed: _create)
                  : null,
            ),
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(padding: const EdgeInsets.all(24), children: const [DPSkeletonList(rows: 4)]);
    }
    if (_error != null) return ListView(children: [DPLoadError(error: _error, onRetry: _load)]);
    if (_cards.isEmpty) return _intro();
    final card = _cards[_index.clamp(0, _cards.length - 1)];
    final status = str(card['status']);
    final usable = status == 'active' || status == 'frozen';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (_cards.length > 1) ...[
          DPChipRow(
            options: [for (final c in _cards) '•••• ${str(c['last4'], 'new')}'],
            selected: '•••• ${str(card['last4'], 'new')}',
            onSelect: (label) => setState(() {
              _index = _cards.indexWhere((c) => '•••• ${str(c['last4'], 'new')}' == label);
            }),
          ),
          const SizedBox(height: 16),
        ],
        DollarCardView(card: card),
        const SizedBox(height: 18),
        if (status == 'creating')
          const DPBanner(
            'Your card is being created. This usually takes a minute — pull down to refresh.',
            tone: DPTone.info,
            icon: DPIcons.pending,
          ),
        if (status == 'terminated')
          const DPBanner(
            'This card has been closed and can\'t be used.',
            tone: DPTone.error,
            icon: DPIcons.alert,
          ),
        if (usable) ...[
          Row(
            children: [
              Expanded(child: _action(DPIcons.plus, 'Add money', status == 'active' ? () => _topUp(card) : null)),
              Expanded(child: _action(DPIcons.downLeft, 'To wallet', status == 'active' ? () => _withdraw(card) : null)),
              Expanded(child: _action(DPIcons.eye, 'Details', () => _reveal(card))),
              Expanded(
                child: _action(DPIcons.snowflake, status == 'frozen' ? 'Unfreeze' : 'Freeze', () => _toggleFreeze(card)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DPCard(
            onTap: () => _history(card),
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const DPIconBadge.blue(DPIcons.history, size: 40, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Card transactions', style: DP.bodyStrong)),
                Icon(DPIcons.chevronRight, color: DP.muted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DPHelper(
            'Use it for online payments in dollars. Keep at least ${usd(toDouble(asMap(_config['fees'])['minimumLeftOnCardUsd'] ?? 1))} on the card — repeated declines for low balance can get a card closed.',
            icon: DPIcons.info,
          ),
        ],
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    final on = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(DP.rLg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: on ? DP.mint : DP.surface, shape: BoxShape.circle),
              child: Icon(icon, color: on ? DP.green : DP.faint, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: DP.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    final fees = asMap(_config['fees']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        const DPHeadline(
          'Pay online in dollars.',
          subtitle: 'A virtual Visa or Mastercard for subscriptions, shopping and ads — funded from your wallet.',
        ),
        const DollarCardView(card: {'status': 'preview', 'brand': 'Visa', 'balanceUsd': 0}),
        const SizedBox(height: 20),
        if (!_available)
          const DPBanner(
            'Dollar cards are launching soon. Please check back later.',
            tone: DPTone.warning,
            icon: DPIcons.pending,
            title: 'Coming soon',
          )
        else ...[
          DPSummaryRow('Card creation', '${usd(toDouble(fees['setupUsd']))} (cards up to \$200)'),
          DPSummaryRow('Top-up fee', '${toDouble(fees['topupPercent'])}%'),
          DPSummaryRow('Load on creation', '${usd(toDouble(_config['minUsd']))} – ${usd(toDouble(_config['maxUsd']))}'),
          const SizedBox(height: 20),
          DPButton(label: 'Get a dollar card', icon: DPIcons.card, onPressed: _create),
        ],
      ],
    );
  }
}

/// The card face: brand, last 4 digits, dollar balance and status.
class DollarCardView extends StatelessWidget {
  final Map<String, dynamic> card;
  const DollarCardView({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final status = str(card['status']);
    final frozen = status == 'frozen';
    final last4 = str(card['last4'], '••••');
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          gradient: frozen
              ? const LinearGradient(colors: [Color(0xFF5B6B86), Color(0xFF3A475E)])
              : DP.navyGradient,
          borderRadius: BorderRadius.circular(DP.rXl),
          boxShadow: DP.glow(DP.navy),
        ),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Dalabapay', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (status != 'active' && status != 'preview')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(DP.rPill),
                    ),
                    child: Text(
                      {'creating': 'Creating…', 'frozen': 'Frozen', 'terminated': 'Closed'}[status] ?? status,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                usd(toDouble(card['balanceUsd'])),
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text('Card balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            const Spacer(),
            Row(
              children: [
                Text(
                  '••••  ••••  ••••  $last4',
                  style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.2, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  str(card['brand'], 'Visa').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            if (str(card['validMonthYear']).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Valid thru ${str(card['validMonthYear'])}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardHistory extends StatefulWidget {
  final String cardId;
  final ScrollController scroll;
  const _CardHistory({required this.cardId, required this.scroll});

  @override
  State<_CardHistory> createState() => _CardHistoryState();
}

class _CardHistoryState extends State<_CardHistory> {
  List<Map<String, dynamic>>? _rows;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = asList(await api.get('/api/cards/${widget.cardId}/transactions'));
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        const DPSheetHandle(),
        const SizedBox(height: 8),
        Text('Card transactions', style: DP.title),
        const SizedBox(height: 12),
        if (_error != null)
          DPLoadError(error: _error, onRetry: _load)
        else if (rows == null)
          const DPSkeletonList(rows: 4)
        else if (rows.isEmpty)
          const DPEmptyState(icon: DPIcons.card, title: 'No card transactions yet')
        else
          for (final t in rows)
            DPListRow(
              leading: DPIconBadge(
                t['direction'] == 'credit' ? DPIcons.downLeft : DPIcons.upRight,
                color: str(t['status']) == 'failed' ? DP.red : (t['direction'] == 'credit' ? DP.green : DP.navyIcon),
                background: str(t['status']) == 'failed' ? DP.redBg : DP.mint,
                size: 40,
                iconSize: 18,
              ),
              title: str(t['description'], 'Card transaction'),
              subtitle: [
                if (t['createdAt'] != null) dateTimeLabel(parseDate(t['createdAt'])),
                if (str(t['status']) == 'failed') 'Declined',
              ].join(' · '),
              trailing: Text(
                '${t['direction'] == 'credit' ? '+' : '-'}${usd(toDouble(t['amountUsd']))}',
                style: DP.bodyStrong.copyWith(
                  color: str(t['status']) == 'failed' ? DP.faint : (t['direction'] == 'credit' ? DP.green : DP.ink),
                ),
              ),
            ),
      ],
    );
  }
}
