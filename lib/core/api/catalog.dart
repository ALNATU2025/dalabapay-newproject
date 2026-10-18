// lib/core/api/catalog.dart
// Small cached lookups shared by the bill screens: networks, per-service
// limits, which services are switched on, and recent recipients.
import '../format.dart';
import 'api.dart';

class ServiceLimit {
  final double minimum;
  final double? perTxn;
  final double? daily;
  const ServiceLimit({this.minimum = 0, this.perTxn, this.daily});

  /// "Minimum ₦50 · Maximum ₦50,000"
  String describe(String Function(num) money) {
    final parts = <String>[];
    if (minimum > 0) parts.add('Minimum ${money(minimum)}');
    if (perTxn != null) parts.add('Maximum ${money(perTxn!)}');
    return parts.join(' · ');
  }

  /// Error message for [amount], or null when it's allowed.
  String? check(double amount, String Function(num) money) {
    if (amount <= 0) return 'Enter an amount';
    if (minimum > 0 && amount < minimum) {
      return 'The minimum is ${money(minimum)}';
    }
    if (perTxn != null && amount > perTxn!) {
      return 'The maximum per payment is ${money(perTxn!)}';
    }
    return null;
  }
}

class Catalog {
  Catalog._();

  static List<Map<String, dynamic>>? _networks;
  static Map<String, ServiceLimit>? _limits;
  static DateTime? _limitsAt;

  /// [{id:'mtn', name:'MTN'}, ...]
  static Future<List<Map<String, dynamic>>> networks() async {
    _networks ??= asList(await api.get('/api/services/networks'));
    return _networks!;
  }

  static Future<Map<String, ServiceLimit>> limits({bool force = false}) async {
    if (!force &&
        _limits != null &&
        DateTime.now().difference(_limitsAt!) < const Duration(minutes: 2)) {
      return _limits!;
    }
    final data = asMap(await api.get('/api/services/limits'));
    _limits = data.map((k, v) {
      final m = asMap(v);
      return MapEntry(
        k,
        ServiceLimit(
          minimum: toDouble(m['minimum']),
          perTxn: m['perTxn'] == null ? null : toDouble(m['perTxn']),
          daily: m['daily'] == null ? null : toDouble(m['daily']),
        ),
      );
    });
    _limitsAt = DateTime.now();
    return _limits!;
  }

  static Future<ServiceLimit> limitFor(String service) async {
    try {
      return (await limits())[service] ?? const ServiceLimit();
    } catch (_) {
      return const ServiceLimit();
    }
  }

  /// Recent successful purchases for a service, newest first, one per
  /// recipient: [{recipient, metadata, ...transaction}].
  static Future<List<Map<String, dynamic>>> recentRecipients(
    String service, {
    int max = 5,
  }) async {
    try {
      final items = itemsOf(await api.get('/api/transactions',
          query: {'type': service, 'status': 'success', 'limit': 30}));
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final t in items) {
        final r = str(t['recipient']);
        if (r.isEmpty || !seen.add(r)) continue;
        out.add(t);
        if (out.length >= max) break;
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}

/// A priced option from the provider (data plan, TV package, PIN type…).
class Plan {
  final String code;
  final String name;
  final double price;
  final String? validity;
  const Plan(this.code, this.name, this.price, [this.validity]);

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        str(j['code']),
        str(j['name']),
        toDouble(j['amount']),
        j['validity']?.toString(),
      );

  static List<Plan> listFrom(dynamic v) => asList(v).map(Plan.fromJson).toList();

  @override
  bool operator ==(Object other) => other is Plan && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
