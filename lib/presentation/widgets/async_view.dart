// lib/presentation/widgets/async_view.dart
// Loading / error / retry wrapper for screens that read from the API.
import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../ui/ui.dart';

/// Loads data with [load] and draws it with [builder]. Shows a spinner while
/// loading and an error with "Try again" when the request fails. Call the
/// `reload` passed to [builder] after changes.
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Widget? loading;
  final EdgeInsetsGeometry padding;

  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.loading,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (_data == null) setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      if (_data != null) dpSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) return widget.builder(context, data, _reload);
    if (_loading) return widget.loading ?? const DPLoading();
    return Padding(
      padding: widget.padding,
      child: DPLoadError(error: _error, onRetry: _reload),
    );
  }
}

class DPLoading extends StatelessWidget {
  final double padding;
  const DPLoading({super.key, this.padding = 40});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: DP.green),
        ),
      ),
    );
  }
}

class DPLoadError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const DPLoadError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final network = error is ApiException && (error as ApiException).isNetwork;
    return Center(
      child: DPEmptyState(
        icon: network ? DPIcons.wifi : DPIcons.alert,
        title: network ? 'You\'re offline' : 'Couldn\'t load this',
        message: error == null ? null : errorMessage(error!),
        actionLabel: 'Try again',
        onAction: onRetry,
      ),
    );
  }
}

/// Runs [action] showing errors as a snackbar. Returns the result or null.
Future<T?> runWithFeedback<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? success,
}) async {
  try {
    final r = await action();
    if (success != null && context.mounted) {
      dpSnack(context, success, success: true);
    }
    return r;
  } catch (e) {
    if (context.mounted) dpSnack(context, errorMessage(e), error: true);
    return null;
  }
}
