// lib/presentation/screens/admin/admin_hawa_page.dart
// Hawa, the admin AI assistant. Type or talk to her (mic); she answers from
// live data with the admin's own permissions and can read answers aloud.
// She prepares buttons (confirm a top-up, approve an account, send a
// message...) that run only after the admin confirms.
//
// Opened with arguments: {'voice': true} → starts listening (app-icon
// shortcut "Talk to Hawa"); {'speak': text} → reads an alert aloud (tapped
// alert notification).
// POST /api/admin/hawa/chat, GET /api/admin/hawa/status.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api.dart';
import '../../../core/format.dart';
import '../../../core/hawa_voice.dart';
import '../../../ui/ui.dart';
import 'admin_widgets.dart';

const _hawaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7C3AED), Color(0xFF2779FD), Color(0xFF079A68)],
);
const _purple = Color(0xFF7C3AED);

const _toolLabels = {
  'dashboard_stats': 'Dashboard',
  'search_users': 'Users',
  'get_user': 'User profile',
  'user_history': 'User history',
  'search_transactions': 'Transactions',
  'get_transaction': 'Transaction details',
  'pending_bank_funding': 'Bank top-ups',
  'approvals_summary': 'Approvals',
  'accounts_to_approve': 'Accounts to approve',
  'kyc_requests': 'KYC requests',
  'refund_queue': 'Refund queue',
  'disputes': 'Disputes',
  'alerts': 'Alerts',
  'settings': 'Settings',
  'commission_rates': 'Commission',
  'provider_status': 'Providers',
};

class HawaMessage {
  final String role; // user | assistant
  final String text;
  final List<String> tools;
  final List<Map<String, dynamic>> actions;
  final bool error;
  final bool local; // not sent to the server (welcome, errors, confirmations)
  final bool alert; // an alert Hawa read out
  const HawaMessage(this.role, this.text,
      {this.tools = const [], this.actions = const [], this.error = false, this.local = false, this.alert = false});
}

class AdminHawaPage extends StatefulWidget {
  /// For tests and screenshots: start with these messages, skip the status call.
  @visibleForTesting
  final List<HawaMessage>? initialMessages;
  @visibleForTesting
  final bool? configured;

  const AdminHawaPage({super.key, this.initialMessages, this.configured});

  @override
  State<AdminHawaPage> createState() => _AdminHawaPageState();
}

class _AdminHawaPageState extends State<AdminHawaPage> {
  static const _welcome = HawaMessage(
    'assistant',
    "Hi, I'm Hawa 👋 Ask me anything about Dalabapay, for Nigeria or Sierra Leone: type, or tap the mic and talk. "
        'I can also prepare actions for you, like confirming a top-up, approving an account or sending a message. '
        'You always confirm first.',
    local: true,
  );
  static const _suggestions = [
    "What's going on right now?",
    'Any bank top-ups to confirm?',
    'Who is waiting for approval?',
    'Show the latest failed payments and why they failed',
    "Today's summary for Nigeria",
  ];
  static final _yes = RegExp(r'^\s*(yes|yeah|yep|ok|okay|confirm|do it|go ahead|approve it|send it)\b', caseSensitive: false);

  final _voice = HawaVoice.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final List<HawaMessage> _messages = [...(widget.initialMessages ?? const [_welcome])];
  final Set<String> _done = {};
  bool _thinking = false;
  bool? _configured;
  String _model = '';
  bool _argsRead = false;
  bool _lastWasVoice = false;

  @override
  void initState() {
    super.initState();
    _configured = widget.configured;
    if (widget.configured == null) _checkStatus();
    _voice.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    final speak = args['speak']?.toString() ?? '';
    if (speak.isNotEmpty) {
      _messages.add(HawaMessage('assistant', speak, local: true, alert: true));
      WidgetsBinding.instance.addPostFrameCallback((_) => _voice.speak('Hawa here. $speak'));
    } else if (args['voice'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startListening(greet: true));
    }
  }

  @override
  void dispose() {
    _voice.stopListening();
    _voice.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final s = asMap(await api.get('/api/admin/hawa/status'));
      if (!mounted) return;
      setState(() {
        _configured = s['configured'] == true;
        _model = str(s['model']);
      });
    } catch (_) {
      if (mounted) setState(() => _configured = true); // let the chat report the problem
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  // ── Voice ─────────────────────────────────────────────────
  Future<void> _startListening({bool greet = false}) async {
    if (_thinking || _configured == false) return;
    if (_voice.listening.value) {
      await _voice.stopListening();
      return;
    }
    HapticFeedback.mediumImpact();
    final ok = await _voice.listen(
      onWords: (w) {
        if (!mounted) return;
        _input.text = w;
        _input.selection = TextSelection.collapsed(offset: w.length);
        setState(() {});
      },
      onDone: (w) {
        if (!mounted) return;
        final words = w.trim();
        if (words.isEmpty) return;
        _input.clear();
        _heard(words);
      },
    );
    if (!ok && mounted) {
      dpSnack(context, 'The microphone is not available. Allow microphone access for Dalabapay, or type your question.',
          error: true);
    } else if (ok && greet && mounted) {
      dpSnack(context, "I'm listening…");
    }
  }

  /// A spoken "yes" right after Hawa offered one button opens its confirm.
  void _heard(String words) {
    final last = _messages.isEmpty ? null : _messages.last;
    if (last != null && last.role == 'assistant' && last.actions.length == 1 && _yes.hasMatch(words)) {
      final key = '${_messages.length - 1}-0';
      if (!_done.contains(key)) {
        setState(() => _messages.add(HawaMessage('user', words, local: true)));
        _confirm(last.actions.first, key);
        return;
      }
    }
    _send(words, true);
  }

  // ── Chat ──────────────────────────────────────────────────
  Future<void> _send([String? preset, bool voice = false]) async {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty || _thinking) return;
    HapticFeedback.selectionClick();
    await _voice.stop();
    _input.clear();
    _lastWasVoice = voice;
    setState(() {
      _messages.add(HawaMessage('user', q));
      _thinking = true;
    });
    _toBottom();
    final history = _messages.where((m) => !m.local && !m.error).toList();
    final recent = history.length > 20 ? history.sublist(history.length - 20) : history;
    try {
      final r = asMap(await api.post('/api/admin/hawa/chat', {
        'messages': [
          for (final m in recent) {'role': m.role, 'content': m.text},
        ],
        if (voice) 'voice': true,
      }));
      if (!mounted) return;
      final reply = str(r['reply']);
      setState(() {
        _messages.add(HawaMessage(
          'assistant',
          reply,
          tools: [for (final t in (r['tools'] as List? ?? const [])) str(asMap(t)['name'])],
          actions: [for (final a in (r['actions'] as List? ?? const [])) asMap(a)],
        ));
        _thinking = false;
      });
      if (_voice.spokenReplies.value || voice) _voice.speak(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(HawaMessage('assistant', errorMessage(e), error: true, local: true));
        _thinking = false;
      });
      if (voice) _voice.speak(errorMessage(e));
    }
    _toBottom();
  }

  void _retry() {
    final lastQ = _messages.lastWhere((m) => m.role == 'user', orElse: () => const HawaMessage('user', ''));
    if (lastQ.text.isEmpty) return;
    setState(() => _messages.removeRange(_messages.lastIndexOf(lastQ), _messages.length));
    _send(lastQ.text, _lastWasVoice);
  }

  void _clear() {
    _voice.stop();
    setState(() {
      _messages
        ..clear()
        ..add(_welcome);
      _done.clear();
    });
  }

  // ── Actions (admin confirms) ─────────────────────────────
  Future<void> _confirm(Map<String, dynamic> a, String key) async {
    final danger = a['danger'] == true;
    final summary = str(a['summary']);
    if (_voice.spokenReplies.value) _voice.speak('${str(a['label'])}. Tap confirm to do it.');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: DP.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (danger ? DP.red : _purple).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(danger ? Icons.warning_amber_rounded : Icons.auto_awesome, color: danger ? DP.red : _purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(str(a['label'], 'Confirm'), style: DP.title)),
                ],
              ),
              const SizedBox(height: 14),
              Text(summary, style: DP.body.copyWith(fontSize: 14.5, height: 1.45)),
              const SizedBox(height: 8),
              Text('Prepared by Hawa · done with your admin account and recorded in the audit log.', style: DP.caption),
              const SizedBox(height: 18),
              DPButton(
                label: danger ? 'Yes, ${str(a['label']).toLowerCase()}' : 'Confirm',
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 6),
              Center(child: DPTextLink(label: 'Not now', onTap: () => Navigator.pop(ctx, false))),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final path = str(a['path']);
    if (!path.startsWith('/api/admin/')) return;
    final body = Map<String, dynamic>.from(asMap(a['body']));
    try {
      switch (str(a['method']).toUpperCase()) {
        case 'PATCH':
          await api.patch(path, body);
          break;
        default:
          await api.post(path, body);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final done = str(a['done'], 'Done.');
      setState(() {
        _done.add(key);
        _messages.add(HawaMessage('assistant', '✅ $done', local: true));
      });
      if (_voice.spokenReplies.value) _voice.speak(done);
      _toBottom();
    } catch (e) {
      if (!mounted) return;
      dpSnack(context, errorMessage(e), error: true);
      if (_voice.spokenReplies.value) _voice.speak('That did not work. ${errorMessage(e)}');
    }
  }

  // ── Voice settings ───────────────────────────────────────
  void _voiceSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: DP.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('Hawa voice', style: DP.title),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _voice.spokenReplies,
                builder: (_, on, __) => SwitchListTile.adaptive(
                  value: on,
                  onChanged: _voice.setSpokenReplies,
                  title: const Text('Read answers aloud'),
                  subtitle: const Text('Hawa speaks her replies.'),
                  activeColor: _purple,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _voice.spokenAlerts,
                builder: (_, on, __) => SwitchListTile.adaptive(
                  value: on,
                  onChanged: _voice.setSpokenAlerts,
                  title: const Text('Speak alerts'),
                  subtitle: const Text('Failed payments, low VTpass wallet and top-ups to confirm are read aloud when the app is open.'),
                  activeColor: _purple,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 18, color: DP.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Quick start: long-press the Dalabapay icon on your home screen and tap "Talk to Hawa". '
                        'Tapping an alert notification opens Hawa and she reads it to you.',
                        style: DP.caption.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showSuggestions = !_thinking && _messages.every((m) => m.role != 'user');
    return AdminScaffold(
      title: 'Ask Hawa',
      breadcrumb: _model.isEmpty ? 'Admin · AI assistant' : 'Admin · AI assistant · $_model',
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _voice.speaking,
          builder: (_, talking, __) => ValueListenableBuilder<bool>(
            valueListenable: _voice.spokenReplies,
            builder: (_, on, __) => IconButton(
              tooltip: talking ? 'Stop talking' : (on ? 'Voice on' : 'Voice off'),
              onPressed: talking ? _voice.stop : _voiceSettings,
              icon: Icon(
                talking ? Icons.stop_circle_outlined : (on ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                color: talking ? DP.red : DP.navyInk,
                size: 20,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'New chat',
          onPressed: _thinking ? null : _clear,
          icon: Icon(Icons.add_comment_outlined, color: DP.navyInk, size: 20),
        ),
      ],
      body: Column(
        children: [
          if (_configured == false) _notSetUp(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                for (var i = 0; i < _messages.length; i++)
                  DPAppear(key: ValueKey('m$i'), child: _bubble(_messages[i], i)),
                if (_thinking) const _Thinking(),
                if (showSuggestions) ...[
                  const SizedBox(height: 8),
                  Text('Try asking', style: DP.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 15, color: _purple),
                          label: Text(s, style: DP.body.copyWith(fontSize: 12.5)),
                          backgroundColor: DP.surface,
                          side: BorderSide(color: DP.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onPressed: _configured == false ? null : () => _send(s),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _notSetUp() => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DP.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DP.rMd),
          border: Border.all(color: DP.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.key_rounded, color: DP.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Hawa isn't set up yet. Add ANTHROPIC_API_KEY in Render → Environment, then try again.",
                style: DP.body.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      );

  Widget _avatar() => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(gradient: _hawaGradient, shape: BoxShape.circle, boxShadow: DP.glow(_purple, strength: 0.4)),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
      );

  Widget _bubble(HawaMessage m, int index) {
    final mine = m.role == 'user';
    final isLast = index == _messages.length - 1;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: mine ? DP.navyGradient : null,
        color: mine
            ? null
            : (m.error ? DP.red.withValues(alpha: 0.08) : (m.alert ? DP.amber.withValues(alpha: 0.10) : DP.surface)),
        border: mine
            ? null
            : Border.all(
                color: m.error ? DP.red.withValues(alpha: 0.3) : (m.alert ? DP.amber.withValues(alpha: 0.5) : DP.border)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.alert)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_active_rounded, size: 15, color: DP.amber),
                  const SizedBox(width: 5),
                  Text('Alert', style: DP.caption.copyWith(fontWeight: FontWeight.w800, color: DP.amber)),
                ],
              ),
            ),
          SelectableText.rich(
            _rich(m.text, DP.body.copyWith(fontSize: 14, height: 1.45, color: mine ? Colors.white : (m.error ? DP.red : DP.ink))),
          ),
          if (m.tools.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.manage_search_rounded, size: 13, color: DP.muted),
                Text('Checked:', style: DP.caption.copyWith(fontSize: 11)),
                for (final t in {...m.tools.where(_toolLabels.containsKey)})
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: DP.borderSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_toolLabels[t]!, style: DP.caption.copyWith(fontSize: 10.5)),
                  ),
              ],
            ),
          ],
          if (!mine && !m.error && !m.local)
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _voice.speak(m.text),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.volume_up_rounded, size: 16, color: DP.muted),
                ),
              ),
            ),
          if (m.alert && isLast)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: () => _send('Tell me more about this alert and what I should do: ${m.text}'), child: const Text('What should I do?')),
                  TextButton(onPressed: () => _send("What's going on right now?"), child: const Text("What's going on?")),
                ],
              ),
            ),
          if (m.error && isLast)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try again'),
              ),
            ),
        ],
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
              if (!mine) ...[_avatar(), const SizedBox(width: 8)],
              Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: bubble)),
              if (mine) const SizedBox(width: 4),
            ],
          ),
          if (m.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (var j = 0; j < m.actions.length; j++) _actionButton(m.actions[j], '$index-$j')],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(Map<String, dynamic> a, String key) {
    final done = _done.contains(key);
    final danger = a['danger'] == true;
    final color = danger ? DP.red : _purple;
    return Material(
      color: done ? DP.green.withValues(alpha: 0.12) : (danger ? color.withValues(alpha: 0.10) : color),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: done ? null : () => _confirm(a, key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.check_circle_rounded : (danger ? Icons.warning_amber_rounded : Icons.bolt_rounded),
                  size: 16, color: done ? DP.green : (danger ? color : Colors.white)),
              const SizedBox(width: 6),
              Text(
                done ? 'Done' : str(a['label'], 'Confirm'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: done ? DP.green : (danger ? color : Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **bold** and "- " / "• " bullets, nothing more.
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
    final enabled = _configured != false;
    return Container(
      decoration: BoxDecoration(color: DP.surface, border: Border(top: BorderSide(color: DP.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ValueListenableBuilder<bool>(
            valueListenable: _voice.listening,
            builder: (_, listening, __) {
              final hasText = _input.text.trim().isNotEmpty;
              final showMic = listening || !hasText;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: enabled && !listening,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      onChanged: (_) => setState(() {}),
                      style: DP.body.copyWith(fontSize: 14.5),
                      decoration: InputDecoration(
                        hintText: listening ? 'Listening… speak now' : 'Ask Hawa, or tap the mic…',
                        counterText: '',
                        filled: true,
                        fillColor: listening ? _purple.withValues(alpha: 0.06) : DP.bg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: DP.border)),
                        enabledBorder:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: DP.border)),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: listening ? _purple : DP.border, width: listening ? 1.5 : 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _purple, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  showMic
                      ? _MicButton(
                          listening: listening,
                          enabled: enabled && !_thinking,
                          onTap: () => _startListening(),
                        )
                      : Semantics(
                          button: true,
                          label: 'Send',
                          child: Material(
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: Ink(
                              decoration: const BoxDecoration(gradient: _hawaGradient, shape: BoxShape.circle),
                              child: InkWell(
                                onTap: enabled && !_thinking ? () => _send() : null,
                                child: const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The microphone: pulses while listening.
class _MicButton extends StatefulWidget {
  final bool listening;
  final bool enabled;
  final VoidCallback onTap;
  const _MicButton({required this.listening, required this.enabled, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.listening) _c.repeat();
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_c.isAnimating) _c.repeat();
    if (!widget.listening && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop listening' : 'Talk to Hawa',
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: SizedBox(
          width: 50,
          height: 50,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Stack(
              alignment: Alignment.center,
              children: [
                if (widget.listening)
                  Container(
                    width: 50 + 14 * _c.value,
                    height: 50 + 14 * _c.value,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: DP.red.withValues(alpha: 0.25 * (1 - _c.value))),
                  ),
                child!,
              ],
            ),
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.45,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.listening ? null : _hawaGradient,
                  color: widget.listening ? DP.red : null,
                ),
                child: Icon(widget.listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hawa is looking things up: three bouncing dots.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(gradient: _hawaGradient, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: DP.surface,
              border: Border.all(color: DP.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Transform.translate(
                          offset: Offset(0, -3 * _bounce((_c.value - i * 0.15) % 1)),
                          child: Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: 0.5 + 0.5 * _bounce((_c.value - i * 0.15) % 1)),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('Hawa is checking…', style: DP.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _bounce(double t) => t < 0.5 ? (t < 0.25 ? t * 4 : (0.5 - t) * 4) : 0;
}
