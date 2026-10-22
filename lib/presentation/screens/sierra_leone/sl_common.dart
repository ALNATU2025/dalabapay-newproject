// lib/presentation/screens/sierra_leone/sl_common.dart
// Shared bits for the Sierra Leone service screens.
import 'package:flutter/material.dart';

import '../../../core/api/catalog.dart';
import '../../../ui/ui.dart';

/// Shown while a Sierra Leone service isn't connected to its provider yet:
/// the screen can be explored but nothing can be paid.
class SlComingSoon extends StatelessWidget {
  final String service;
  const SlComingSoon(this.service, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DPBanner(
        '$service in Sierra Leone is launching soon. You can look around, but payments open once it\'s switched on.',
        tone: DPTone.warning,
        icon: DPIcons.pending,
        title: 'Coming soon',
      ),
    );
  }
}

/// Loads whether [service] can be paid; rebuilds with the answer.
mixin SlAvailability<T extends StatefulWidget> on State<T> {
  bool slConnected = true;

  Future<void> checkAvailability(String service) async {
    final ok = await Catalog.connected(service);
    if (mounted) setState(() => slConnected = ok);
  }
}

/// Sierra Leone mobile number in local form (076123456), or null.
String? slPhone(String raw) => DPCountry.sierraLeone.localPhone(raw);
