// lib/core/dev_code.dart
// While the backend runs without email (development), it returns the
// 6-digit code as `devCode` so you can test sign-up and resets.
import 'package:flutter/material.dart';

import '../ui/ui.dart';
import 'format.dart';

void showDevCode(BuildContext context, dynamic response) {
  final code = asMap(response)['devCode'];
  if (code == null || !context.mounted) return;
  dpSnack(context, 'Test mode: your code is $code');
}
