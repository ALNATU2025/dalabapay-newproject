// lib/core/format.dart
// Date helpers and safe JSON readers shared by the screens.

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Parses an ISO date from the API (falls back to now).
DateTime parseDate(dynamic v) {
  if (v is DateTime) return v.toLocal();
  return DateTime.tryParse('${v ?? ''}')?.toLocal() ?? DateTime.now();
}

/// "5 mins ago", "Yesterday", "12 Jan" — for list subtitles.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hrs ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${d.day} ${_months[d.month - 1]}';
}

/// "18 Jan 2026, 14:05"
String dateTimeLabel(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $hh:$mm';
}

/// "18 Jan 2026"
String dateLabel(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "2026-01-18" for API date filters.
String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

double toDouble(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int toInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
String str(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> asList(dynamic v) =>
    v is List ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : [];

/// Items of a paged list response `{ items, total, ... }`.
List<Map<String, dynamic>> itemsOf(dynamic v) => asList(asMap(v)['items']);
