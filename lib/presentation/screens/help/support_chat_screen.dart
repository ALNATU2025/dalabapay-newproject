// lib/presentation/screens/help/support_chat_screen.dart
// Chat with Aminata, Dalabapay's AI support. She greets the customer by
// name as soon as the chat opens, answers from their own account, and can
// offer buttons: submit a problem report, open a screen, or WhatsApp a
// person. POST /api/support/chat, GET /api/support/status.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api.dart';
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/ui.dart';

const _aminataGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF079A68), Color(0xFF0EA5A4), Color(0xFF2779FD)],
);
const supportWhatsApp = '2349163207050';

class SupportMessage {
  final String role; // user | assistant
  final String text;
  final List<Map<String, dynamic>> actions;
  final bool error;
  final bool local; // not sent to the server (greeting, errors, confirmations)
  const SupportMessage(this.role, this.text, {this.actions = const [], this.error = false, this.local = false});
}

/// The conversation stays while the app is open (per signed-in user).
final Map<String, List<SupportMessage>> _chats = {};

class SupportChatScreen extends StatefulWidget {
  /// For tests and screenshots.
  @visibleForTesting
  final List<SupportMessage>? initialMessages;
  @visibleForTesting
  final bool? available;
  @visibleForTesting
  final String? firstName;

  const SupportChatScreen({super.key, this.initialMessages, this.available, this.firstName});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const _suggestions = [
    'My payment failed',
    "I didn't receive my airtime or data",
    'How do I add money?',
    'Why is my account pending?',
    'I want to talk to a person',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final List<SupportMessage> _messages;
  final Set<String> _done = {}; // actions already used
  bool _thinking = false;
  bool? _available;

  String get _first {
    final n = widget.firstName ?? Session.instance.user?.firstName ?? '';
    return n.trim().isEmpty ? 'there' : n.trim();
  }

  SupportMessage get _greeting => SupportMessage(
        'assistant',
        "Hi $_first 👋 I'm Aminata, your Dalabapay assistant. I can check your payments, explain what happened "
            'and help you fix it. How can I help you today?',
        local: true,
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialMessages != null) {
      _messages = [...widget.initialMessages!];
    } else {
      final key = Session.instance.user?.id ?? '';
      _messages = _chats.putIfAbsent(key, () => [_greeting]);
    }
    _available = widget.available;
    if (widget.available == null) _checkStatus();
    _toBottom(animate: false);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final s = asMap(await api.get('/api/support/status'));
      if (mounted) setState(() => _available = s['available'] == true);
    } catch (_) {
      if (mounted) setState(() => _available = true);
    }
  }

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent + 80;
      animate
          ? _scroll.animateTo(end, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
          : _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty || _thinking) return;
    HapticFeedback.selectionClick();
    _input.clear();
    setState(() {
      _messages.add(SupportMessage('user', q));
      _thinking = true;
    });
    _toBottom();
    final history = _messages.where((m) => !m.local && !m.error).toList();
    final recent = history.length > 20 ? history.sublist(history.length - 20) : history;
    try {
      final r = asMap(await api.post('/api/support/chat', {
        'messages': [
          for (final m in recent) {'role': m.role, 'content': m.text},
        ],
      }));
      if (!mounted) return;
      setState(() {
        _messages.add(SupportMessage(
          'assistant',
          str(r['reply']),
          actions: [for (final a in (r['actions'] as List? ?? const [])) asMap(a)],
        ));
        _thinking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(SupportMessage('assistant', errorMessage(e),
            error: true,
            local: true,
            actions: const [
              {'type': 'contact_human', 'label': 'Chat with our team on WhatsApp', 'message': ''},
            ]));
        _thinking = false;
      });
    }
    _toBottom();
  }

  void _newChat() {
    setState(() {
      _messages
        ..clear()
        ..add(_greeting);
      _done.clear();
    });
  }

  // ── Buttons Aminata offers ─────────────────────────────────
  Future<void> _runAction(Map<String, dynamic> a, String key) async {
    switch (str(a['type'])) {
      case 'open_screen':
        final route = str(a['route']);
        if (route.startsWith('/')) Navigator.pushNamed(context, route);
        break;
      case 'contact_human':
        final msg = str(a['message']);
        final uri = Uri.parse('https://wa.me/$supportWhatsApp${msg.isEmpty ? '' : '?text=${Uri.encodeComponent(msg)}'}');
        bool opened = false;
        try {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
        if (!opened && mounted) dpSnack(context, 'WhatsApp us on +$supportWhatsApp');
        break;
      case 'report_problem':
        await _report(a, key);
        break;
    }
  }

  Future<void> _report(Map<String, dynamic> a, String key) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: DP.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send this report to our team?', style: DP.title),
              const SizedBox(height: 12),
              _kv('Payment', str(a['reference'])),
              _kv('Problem', str(a['reason'])),
              if (str(a['description']).isNotEmpty) _kv('Details', str(a['description'])),
              const SizedBox(height: 8),
              Text("We'll review it and update you in My reports.", style: DP.caption),
              const SizedBox(height: 16),
              DPButton(label: 'Submit report', onPressed: () => Navigator.pop(ctx, true)),
              const SizedBox(height: 6),
              Center(child: DPTextLink(label: 'Not now', onTap: () => Navigator.pop(ctx, false))),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.post('/api/disputes', {
        'transactionId': str(a['transactionId']),
        'type': str(a['disputeType'], 'other'),
        'reason': str(a['reason']),
        if (str(a['description']).isNotEmpty) 'description': str(a['description']),
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _done.add(key);
        _messages.add(SupportMessage(
          'assistant',
          "Done ✅ Your report about ${str(a['reference'])} has been sent to our team. You can follow it in My reports. Anything else I can help with?",
          local: true,
          actions: const [
            {'type': 'open_screen', 'label': 'Open my reports', 'route': '/user-disputes'},
          ],
        ));
      });
      _toBottom();
    } catch (e) {
      if (mounted) dpSnack(context, errorMessage(e), error: true);
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 72, child: Text(k, style: DP.caption)),
            Expanded(child: Text(v, style: DP.body.copyWith(fontSize: 14))),
          ],
        ),
      );

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showSuggestions = !_thinking && _messages.every((m) => m.role != 'user');
    return Scaffold(
      backgroundColor: DP.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            if (_available == false) _unavailable(),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  for (var i = 0; i < _messages.length; i++)
                    DPAppear(key: ValueKey('s$i'), child: _bubble(_messages[i], i)),
                  if (_thinking) const _Typing(),
                  if (showSuggestions && _available != false) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in _suggestions)
                            ActionChip(
                              label: Text(s, style: DP.body.copyWith(fontSize: 13)),
                              backgroundColor: DP.surface,
                              side: BorderSide(color: DP.green.withValues(alpha: 0.35)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onPressed: () => _send(s),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(color: DP.surface, border: Border(bottom: BorderSide(color: DP.border))),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(DPIcons.back, color: DP.ink),
            ),
            Stack(
              children: [
                _avatar(40),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: _available == false ? DP.muted : DP.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: DP.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aminata', style: DP.bodyStrong.copyWith(fontSize: 16)),
                  Text(
                    _thinking ? 'typing…' : (_available == false ? 'Away' : 'Dalabapay assistant · replies instantly'),
                    style: DP.caption.copyWith(fontSize: 12, color: _thinking ? DP.green : null),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'New chat',
              onPressed: _thinking ? null : _newChat,
              icon: Icon(Icons.refresh_rounded, color: DP.muted),
            ),
          ],
        ),
      );

  Widget _unavailable() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DP.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DP.rMd),
          border: Border.all(color: DP.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text("Aminata isn't available right now. Our team is on WhatsApp.", style: DP.body.copyWith(fontSize: 13)),
            ),
            TextButton(
              onPressed: () => _runAction(const {'type': 'contact_human', 'message': ''}, 'wa'),
              child: const Text('WhatsApp'),
            ),
          ],
        ),
      );

  Widget _avatar(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(gradient: _aminataGradient, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.45)),
      );

  IconData _actionIcon(String type) => switch (type) {
        'report_problem' => Icons.flag_rounded,
        'contact_human' => Icons.chat_rounded,
        _ => Icons.arrow_forward_rounded,
      };

  Widget _bubble(SupportMessage m, int index) {
    final mine = m.role == 'user';
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? DP.green : (m.error ? DP.red.withValues(alpha: 0.08) : DP.surface),
        border: mine ? null : Border.all(color: m.error ? DP.red.withValues(alpha: 0.3) : DP.border),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: SelectableText.rich(
        _rich(m.text, DP.body.copyWith(fontSize: 14.5, height: 1.45, color: mine ? Colors.white : (m.error ? DP.red : DP.ink))),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[_avatar(30), const SizedBox(width: 8)],
              Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: bubble)),
            ],
          ),
          if (m.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var j = 0; j < m.actions.length; j++) _actionButton(m.actions[j], '$index-$j'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(Map<String, dynamic> a, String key) {
    final type = str(a['type']);
    final done = _done.contains(key);
    final primary = type == 'report_problem';
    final color = type == 'contact_human' ? const Color(0xFF25D366) : (primary ? DP.green : DP.blue);
    return Material(
      color: primary && !done ? color : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: done ? null : () => _runAction(a, key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.check_circle_rounded : _actionIcon(type), size: 16, color: primary && !done ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                done ? 'Report sent' : str(a['label'], 'Open'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary && !done ? Colors.white : color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **bold** and "- " bullets.
  TextSpan _rich(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    for (var li = 0; li < lines.length; li++) {
      var line = lines[li];
      final bullet = RegExp(r'^\s*[-*•]\s+').firstMatch(line);
      if (bullet != null) line = '•  ${line.substring(bullet.end)}';
      final parts = line.split('**');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        spans.add(TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : base));
      }
      if (li < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(children: spans, style: base);
  }

  Widget _composer() {
    final enabled = _available != false;
    final canSend = enabled && !_thinking && _input.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: DP.surface, border: Border(top: BorderSide(color: DP.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  style: DP.body.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Type your message…',
                    counterText: '',
                    filled: true,
                    fillColor: DP.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: DP.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: DP.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: DP.green, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Send',
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: canSend ? 1 : 0.9,
                  child: Material(
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: canSend ? _aminataGradient : null,
                        color: canSend ? null : DP.borderSoft,
                        shape: BoxShape.circle,
                      ),
                      child: InkWell(
                        onTap: canSend ? () => _send() : null,
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.send_rounded, color: canSend ? Colors.white : DP.muted, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _bounce(double t) => t < 0.5 ? (t < 0.25 ? t * 4 : (0.5 - t) * 4) : 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 38),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: DP.surface,
            border: Border.all(color: DP.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Transform.translate(
                    offset: Offset(0, -3 * _bounce((_c.value - i * 0.15) % 1)),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: DP.green.withValues(alpha: 0.45 + 0.55 * _bounce((_c.value - i * 0.15) % 1)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
