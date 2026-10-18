// lib/presentation/screens/admin/admin_mock.dart
// Sample data for the admin console (UI only — nothing comes from a server).

class AdminUser {
  final String id;
  String name;
  String email;
  String phone;
  double balance;
  double commission;
  bool active;
  bool approved;
  String role; // user, admin, finance, support, super
  bool pinLocked;
  final int joinedDaysAgo;
  final int transactions;

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
    required this.joinedDaysAgo,
    this.transactions = 0,
  });

  bool get isAdmin => role != 'user';
}

String roleLabel(String role) => switch (role) {
      'super' => 'Super Admin',
      'admin' => 'Administrator',
      'finance' => 'Finance Officer',
      'support' => 'Support Agent',
      _ => 'User',
    };

final List<AdminUser> kAdminUsers = [
  AdminUser(id: 'U1001', name: 'Adaeze Okafor', email: 'adaeze@example.com', phone: '08034567890', balance: 124850, commission: 3420.5, role: 'super', joinedDaysAgo: 210, transactions: 184),
  AdminUser(id: 'U1002', name: 'Chidi Eze', email: 'chidi.eze@example.com', phone: '08123456789', balance: 18200, commission: 640, joinedDaysAgo: 96, transactions: 52),
  AdminUser(id: 'U1003', name: 'Fatima Bello', email: 'fatima.b@example.com', phone: '07031122334', balance: 5400, commission: 120, joinedDaysAgo: 41, transactions: 17),
  AdminUser(id: 'U1004', name: 'Tunde Adeyemi', email: 'tunde.a@example.com', phone: '09055566677', balance: 0, approved: false, joinedDaysAgo: 1, transactions: 0),
  AdminUser(id: 'U1005', name: 'Ngozi Obi', email: 'ngozi.obi@example.com', phone: '08167788990', balance: 72500, commission: 2150, role: 'finance', joinedDaysAgo: 180, transactions: 96),
  AdminUser(id: 'U1006', name: 'Ibrahim Musa', email: 'ibrahim.m@example.com', phone: '08029988776', balance: 950, active: false, pinLocked: true, joinedDaysAgo: 63, transactions: 23),
  AdminUser(id: 'U1007', name: 'Blessing Udo', email: 'blessing.u@example.com', phone: '07065544332', balance: 31800, commission: 880, role: 'support', joinedDaysAgo: 120, transactions: 61),
  AdminUser(id: 'U1008', name: 'Emeka Nwosu', email: 'emeka.n@example.com', phone: '08143322110', balance: 2300, approved: false, joinedDaysAgo: 2, transactions: 1),
  AdminUser(id: 'U1009', name: 'Aisha Lawal', email: 'aisha.l@example.com', phone: '09012233445', balance: 15600, commission: 410, joinedDaysAgo: 75, transactions: 38),
  AdminUser(id: 'U1010', name: 'Segun Bakare', email: 'segun.b@example.com', phone: '08098877665', balance: 48900, commission: 1290, joinedDaysAgo: 150, transactions: 77),
];

class AdminTxn {
  final String ref;
  final String userName;
  final String userEmail;
  final String service; // Airtime, Data, ...
  final String description;
  final double amount;
  String status; // Successful, Pending, Failed, Refunded, Disputed
  final bool credit;
  final int minutesAgo;
  String? note;

  AdminTxn(
    this.ref,
    this.userName,
    this.userEmail,
    this.service,
    this.description,
    this.amount,
    this.status,
    this.minutesAgo, {
    this.credit = false,
  });
}

final List<AdminTxn> kAdminTxns = [
  AdminTxn('DP1760741001', 'Chidi Eze', 'chidi.eze@example.com', 'Airtime', 'MTN Airtime · 08123456789', 2000, 'Successful', 12),
  AdminTxn('DP1760741002', 'Ngozi Obi', 'ngozi.obi@example.com', 'Fund Wallet', 'Wallet top-up · Bank transfer', 50000, 'Successful', 35, credit: true),
  AdminTxn('DP1760741003', 'Fatima Bello', 'fatima.b@example.com', 'Electricity', 'Ikeja Electric · 45031234567', 10000, 'Pending', 58),
  AdminTxn('DP1760741004', 'Segun Bakare', 'segun.b@example.com', 'Cable TV', 'DSTV Compact · 7023456789', 15700, 'Successful', 95),
  AdminTxn('DP1760741005', 'Aisha Lawal', 'aisha.l@example.com', 'Data', 'Airtel 10GB · 08123456789', 3000, 'Failed', 140),
  AdminTxn('DP1760741006', 'Blessing Udo', 'blessing.u@example.com', 'Transfer', 'Sent to Chidi Eze', 7500, 'Successful', 220),
  AdminTxn('DP1760741007', 'Ibrahim Musa', 'ibrahim.m@example.com', 'Data', 'MTN 2GB · 08029988776', 1500, 'Disputed', 400),
  AdminTxn('DP1760741008', 'Adaeze Okafor', 'adaeze@example.com', 'Education', 'WAEC Result Checker', 3900, 'Successful', 610),
  AdminTxn('DP1760741009', 'Chidi Eze', 'chidi.eze@example.com', 'Insurance', 'Third party motor · LAG-123-XY', 15000, 'Pending', 900),
  AdminTxn('DP1760741010', 'Fatima Bello', 'fatima.b@example.com', 'Intl Airtime', 'Ghana · MTN Ghana', 5250, 'Refunded', 1500),
  AdminTxn('DP1760741011', 'Segun Bakare', 'segun.b@example.com', 'Commission', 'Commission earned', 157, 'Successful', 1700, credit: true),
  AdminTxn('DP1760741012', 'Emeka Nwosu', 'emeka.n@example.com', 'Fund Wallet', 'Wallet top-up · One-time account', 2300, 'Pending', 2900, credit: true),
];

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

class AdminDispute {
  final String ref;
  final String user;
  final String type;
  final String reason;
  final double amount;
  String status; // pending, resolved, rejected
  final bool hasEvidence;
  final int hoursAgo;
  String? resolution;
  AdminDispute(this.ref, this.user, this.type, this.reason, this.amount,
      this.status, this.hasEvidence, this.hoursAgo);
}

final List<AdminDispute> kAdminDisputes = [
  AdminDispute('DP1760741007', 'Ibrahim Musa', 'Service Not Delivered', 'Data not credited to my line', 1500, 'pending', true, 6),
  AdminDispute('DP1760740811', 'Aisha Lawal', 'Incorrect Amount', 'Charged ₦3,000 for a ₦2,500 plan', 500, 'pending', false, 20),
  AdminDispute('DP1760740502', 'Chidi Eze', 'Pending Transaction', 'Electricity token not received', 5000, 'pending', true, 30),
  AdminDispute('DP1760739901', 'Fatima Bello', 'Service Not Delivered', 'Airtime failed but wallet debited', 1000, 'resolved', true, 72),
];

class AdminAlert {
  final String title;
  final String body;
  final String type; // new_user, wallet, duplicate, suspicious, status
  final String severity; // info, warning, critical
  final int minutesAgo;
  bool read;
  AdminAlert(this.title, this.body, this.type, this.severity, this.minutesAgo,
      {this.read = false});
}

final List<AdminAlert> kAdminAlerts = [
  AdminAlert('New user registered', 'Tunde Adeyemi signed up and is awaiting approval.', 'new_user', 'info', 30),
  AdminAlert('Wallet funding successful', 'Ngozi Obi funded ₦50,000 by bank transfer.', 'wallet', 'info', 35),
  AdminAlert('Duplicate attempt blocked', 'Two identical airtime requests from Chidi Eze within 5 seconds.', 'duplicate', 'warning', 80),
  AdminAlert('Suspicious activity', '5 failed PIN attempts on Ibrahim Musa\'s account. PIN locked.', 'suspicious', 'critical', 190, read: true),
  AdminAlert('Status changed', 'DP1760741010 marked Refunded by Adaeze Okafor.', 'status', 'info', 1500, read: true),
];

/// Revenue for the last 7 days (oldest first), sample values.
const List<double> kRevenue7d = [182000, 240500, 198300, 305000, 276400, 351200, 289900];

/// New users for the last 7 days (oldest first).
const List<int> kUsers7d = [4, 7, 5, 9, 6, 11, 8];

String adminAgo(int minutes) {
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '$minutes min ago';
  if (minutes < 60 * 24) return '${minutes ~/ 60} hr ago';
  final d = minutes ~/ (60 * 24);
  return d == 1 ? 'Yesterday' : '$d days ago';
}
