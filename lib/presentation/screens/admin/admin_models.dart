// lib/presentation/screens/admin/admin_models.dart
// Admin console data, read from /api/admin/*. Money is in naira.
import '../../../core/api/session.dart';
import '../../../core/format.dart';
import '../../../ui/dp_tokens.dart';
import '../../widgets/transaction_widgets.dart';

class AdminUser {
  final String id;
  String name;
  String email;
  String phone;
  double balance;
  double commission;
  bool active;
  bool approved;
  String role; // user, support, finance, admin, super
  bool pinLocked;
  bool pinSet;
  final DateTime joined;
  int transactions;
  final String kycStatus;
  final String country; // NG | SL
  String get currency => country == 'SL' ? 'SLE' : 'NGN';
  /// Short country tag for lists ("NG" / "SL").
  String get flag => country;

  /// Money in this user's currency (₦ or Le).
  String money(num? v, {bool decimals = true}) => DP.moneyIn(v, currency, decimals: decimals);

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.balance,
    this.commission = 0,
    this.active = true,
    this.approved = true,
    this.role = 'user',
    this.pinLocked = false,
    this.pinSet = false,
    required this.joined,
    this.transactions = 0,
    this.kycStatus = 'none',
    this.country = 'NG',
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: str(j['id']),
        name: str(j['fullName']),
        email: str(j['email']),
        phone: str(j['phone']),
        balance: toDouble(j['balance']),
        commission: toDouble(j['commissionBalance']),
        active: j['isActive'] != false,
        approved: j['isApproved'] != false,
        role: str(j['role'], 'user'),
        pinLocked: j['pinLocked'] == true,
        pinSet: j['pinSet'] == true,
        joined: parseDate(j['createdAt']),
        transactions: toInt(j['transactions']),
        kycStatus: str(asMap(j['kyc'])['status'], 'none'),
        country: str(j['country'], 'NG'),
      );

  bool get isAdmin => role != 'user';
  int get joinedDaysAgo => DateTime.now().difference(joined).inDays;
}

String roleLabel(String role) => switch (role) {
      'super' => 'Super Admin',
      'admin' => 'Administrator',
      'finance' => 'Finance Officer',
      'support' => 'Support Agent',
      _ => 'User',
    };

/// Display label for an API status.
String statusLabel(String s) => switch (s) {
      'success' => 'Successful',
      'pending' => 'Pending',
      'failed' => 'Failed',
      'refunded' => 'Refunded',
      'disputed' => 'Disputed',
      _ => s.isEmpty ? 'Unknown' : s[0].toUpperCase() + s.substring(1),
    };

/// Label → API status.
const Map<String, String> kStatusValues = {
  'Successful': 'success',
  'Pending': 'pending',
  'Failed': 'failed',
  'Refunded': 'refunded',
  'Disputed': 'disputed',
};

/// Service filter label → transaction type for /api/admin/transactions.
const Map<String, String> kAdminServiceTypes = {
  'Airtime': 'airtime',
  'Data': 'data',
  'Electricity': 'electricity',
  'Cable TV': 'cable',
  'Education': 'education',
  'Insurance': 'insurance',
  'Intl Airtime': 'international',
  'Transfer': 'transfer_out',
  'Fund Wallet': 'wallet_funding',
  'Refund': 'refund',
  'Admin Credit': 'admin_credit',
  'Admin Debit': 'admin_debit',
};

const List<String> kAdminServices = [
  'Airtime',
  'Data',
  'Electricity',
  'Cable TV',
  'Education',
  'Insurance',
  'Intl Airtime',
  'Transfer',
];

String serviceLabel(String type) => switch (type) {
      'airtime' => 'Airtime',
      'data' => 'Data',
      'electricity' => 'Electricity',
      'cable' => 'Cable TV',
      'education' => 'Education',
      'insurance' => 'Insurance',
      'international' => 'Intl Airtime',
      'transfer_out' || 'transfer_in' => 'Transfer',
      'wallet_funding' => 'Fund Wallet',
      'commission' || 'commission_withdrawal' => 'Commission',
      'referral_bonus' => 'Referral',
      'refund' => 'Refund',
      'admin_credit' => 'Admin Credit',
      'admin_debit' => 'Admin Debit',
      _ => transactionTypeLabel(type),
    };

class AdminTxn {
  final String id;
  final String ref;
  final String userId;
  final String userName;
  final String userEmail;
  final String type;
  final String service;
  final String description;
  final double amount;
  final double fee;
  String status; // Successful, Pending, Failed, Refunded, Disputed
  final bool credit;
  final DateTime date;
  final bool refunded;
  String? note;
  final Map<String, dynamic> json;

  AdminTxn.fromJson(Map<String, dynamic> j)
      : json = j,
        id = str(j['id']),
        ref = str(j['reference']),
        userId = str(asMap(j['user'])['id']),
        userName = str(asMap(j['user'])['fullName'], '—'),
        userEmail = str(asMap(j['user'])['email']),
        type = str(j['type']),
        service = serviceLabel(str(j['type'])),
        description = str(j['description']),
        amount = toDouble(j['amount']),
        fee = toDouble(j['fee']),
        status = statusLabel(str(j['status'])),
        credit = j['direction'] == 'credit',
        date = parseDate(j['createdAt']),
        refunded = j['refunded'] == true,
        note = j['adminNote']?.toString();

  int get minutesAgo => DateTime.now().difference(date).inMinutes;
  bool get isPayment => !credit;

  /// "NGN" / "SLE" — admin lists mix both countries.
  String get currency => str(json['currency'], 'NGN');
  String money(num? v, {bool decimals = true}) => DP.moneyIn(v, currency, decimals: decimals);
}

class AdminDispute {
  final String id;
  final String transactionId;
  final String ref;
  final String user;
  final String userEmail;
  final String type;
  final String reason;
  final String description;
  final double amount;
  final String currency;
  String status; // pending, investigating, resolved, rejected
  final DateTime date;
  String? resolution;

  AdminDispute.fromJson(Map<String, dynamic> j)
      : id = str(j['id']),
        transactionId = str(asMap(j['transaction'])['id']),
        ref = str(asMap(j['transaction'])['reference']),
        user = str(asMap(j['user'])['fullName'], '—'),
        userEmail = str(asMap(j['user'])['email']),
        type = disputeTypeLabel(str(j['type'])),
        reason = str(j['reason']),
        description = str(j['description']),
        amount = toDouble(asMap(j['transaction'])['amount']),
        currency = str(asMap(j['transaction'])['currency'], 'NGN'),
        status = str(j['status']),
        date = parseDate(j['createdAt']),
        resolution = j['resolution']?.toString();

  int get hoursAgo => DateTime.now().difference(date).inHours;
  String money(num? v, {bool decimals = true}) => DP.moneyIn(v, currency, decimals: decimals);
  bool get open => status == 'pending' || status == 'investigating';
}

String disputeTypeLabel(String t) => switch (t) {
      'service_not_delivered' => 'Service Not Delivered',
      'incorrect_amount' => 'Incorrect Amount',
      'failed_transaction' => 'Failed Transaction',
      'pending_transaction' => 'Pending Transaction',
      'refund_request' => 'Refund Request',
      _ => 'Other',
    };

class AdminAlert {
  final String id;
  final String title;
  final String body;
  final String type; // new_user, wallet, duplicate, suspicious, status, dispute, provider
  final String severity; // info, warning, critical
  final DateTime date;
  bool read;

  AdminAlert.fromJson(Map<String, dynamic> j)
      : id = str(j['id']),
        title = str(j['title']),
        body = str(j['body']),
        type = str(j['type']),
        severity = str(j['severity'], 'info'),
        date = parseDate(j['createdAt']),
        read = j['read'] == true;

  int get minutesAgo => DateTime.now().difference(date).inMinutes;
}

String adminAgo(int minutes) {
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '$minutes min ago';
  if (minutes < 60 * 24) return '${minutes ~/ 60} hr ago';
  final d = minutes ~/ (60 * 24);
  return d == 1 ? 'Yesterday' : '$d days ago';
}

String agoOf(DateTime d) => adminAgo(DateTime.now().difference(d).inMinutes);

/// Whether the signed-in staff member may do [permission] (mirrors the
/// server's role table; the server still checks every request).
bool adminCan(String permission) =>
    Session.instance.user?.can(permission) ?? false;
