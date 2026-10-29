// lib/core/web_idle.dart
// Website only: signs the person out after 15 minutes without activity, so
// a session isn't left open on a shared or public computer.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api/session.dart';

class WebIdleLogout extends StatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;
  final Duration after;
  const WebIdleLogout({super.key, required this.child, required this.onTimeout, this.after = const Duration(minutes: 15)});

  @override
  State<WebIdleLogout> createState() => _WebIdleLogoutState();
}

class _WebIdleLogoutState extends State<WebIdleLogout> {
  DateTime _last = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _seen() => _last = DateTime.now();

  Future<void> _check() async {
    if (!Session.instance.loggedIn) {
      _seen();
      return;
    }
    if (DateTime.now().difference(_last) < widget.after) return;
    _seen();
    await Session.instance.logout();
    widget.onTimeout();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _seen(),
      onPointerSignal: (_) => _seen(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, __) {
          _seen();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
