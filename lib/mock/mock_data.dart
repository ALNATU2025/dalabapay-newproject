// lib/mock/mock_data.dart
// Sample data so every screen has something to show. Nothing here comes
// from, or goes to, a server — replace it with real data when you wire up
// the backend.

class MockUser {
  MockUser._();
  static const String fullName = 'Adaeze Okafor';
  static const String firstName = 'Adaeze';
  static const String email = 'adaeze@example.com';
  static const String phone = '08034567890';
  static const String referralCode = 'ADAEZE24';
  static const String accountNumber = '9012345678';
  static const String bankName = 'Wema Bank';
  static const double walletBalance = 124850.00;
  static const double commissionBalance = 3420.50;
  static const double totalEarned = 18760.00;
  static const int referrals = 7;
}

/// Recent transactions, newest first. Same keys the real API used, so the
/// list widgets can stay the same once real data arrives.
final List<Map<String, dynamic>> kMockTransactions = [
  {
    'id': 'TXN-240118-0001',
    'type': 'airtime',
    'description': 'MTN Airtime',
    'amount': 2000.0,
    'status': 'success',
    'phone': '08034567890',
    'createdAt': DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
  },
  {
    'id': 'TXN-240118-0002',
    'type': 'wallet_funding',
    'description': 'Wallet Top-up',
    'amount': 50000.0,
    'status': 'success',
    'isCredit': true,
    'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
  },
  {
    'id': 'TXN-240117-0003',
    'type': 'electricity',
    'description': 'Ikeja Electric Prepaid',
    'amount': 10000.0,
    'status': 'success',
    'meterNumber': '45031234567',
    'createdAt': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toIso8601String(),
  },
  {
    'id': 'TXN-240117-0004',
    'type': 'cable',
    'description': 'DSTV Compact',
    'amount': 15700.0,
    'status': 'pending',
    'smartcardNumber': '7023456789',
    'createdAt': DateTime.now().subtract(const Duration(days: 1, hours: 6)).toIso8601String(),
  },
  {
    'id': 'TXN-240116-0005',
    'type': 'commission',
    'description': 'Commission earned',
    'amount': 150.0,
    'status': 'success',
    'isCredit': true,
    'isCommission': true,
    'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
  },
  {
    'id': 'TXN-240115-0006',
    'type': 'data',
    'description': 'Airtel Data 10GB',
    'amount': 3000.0,
    'status': 'failed',
    'phone': '08123456789',
    'createdAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
  },
  {
    'id': 'TXN-240114-0007',
    'type': 'transfer',
    'description': 'Sent to Chidi Eze',
    'amount': 7500.0,
    'status': 'success',
    'createdAt': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
  },
  {
    'id': 'TXN-240112-0008',
    'type': 'education',
    'description': 'WAEC Result Checker',
    'amount': 3900.0,
    'status': 'success',
    'createdAt': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
  },
];

bool mockIsCredit(Map<String, dynamic> t) => t['isCredit'] == true;

class MockPlan {
  final String name;
  final double price;
  final String? validity;
  const MockPlan(this.name, this.price, [this.validity]);
}

const List<String> kMockNetworks = ['MTN', 'Airtel', 'Glo', '9mobile'];

const List<MockPlan> kMockDataPlans = [
  MockPlan('500MB', 500, '1 day'),
  MockPlan('1GB', 800, '7 days'),
  MockPlan('2GB', 1500, '30 days'),
  MockPlan('5GB', 2500, '30 days'),
  MockPlan('10GB', 3000, '30 days'),
  MockPlan('20GB', 5500, '30 days'),
];

const List<String> kMockCableProviders = ['DSTV', 'GOtv', 'StarTimes', 'Showmax'];

const Map<String, List<MockPlan>> kMockCablePlans = {
  'DSTV': [
    MockPlan('Padi', 3600, '1 month'),
    MockPlan('Yanga', 5100, '1 month'),
    MockPlan('Confam', 9300, '1 month'),
    MockPlan('Compact', 15700, '1 month'),
    MockPlan('Compact Plus', 25000, '1 month'),
    MockPlan('Premium', 37000, '1 month'),
  ],
  'GOtv': [
    MockPlan('Smallie', 1575, '1 month'),
    MockPlan('Jinja', 3300, '1 month'),
    MockPlan('Jolli', 4850, '1 month'),
    MockPlan('Max', 7200, '1 month'),
    MockPlan('Supa', 9600, '1 month'),
  ],
  'StarTimes': [
    MockPlan('Nova', 1700, '1 month'),
    MockPlan('Basic', 3300, '1 month'),
    MockPlan('Smart', 4200, '1 month'),
    MockPlan('Classic', 5000, '1 month'),
  ],
  'Showmax': [
    MockPlan('Mobile', 1450, '1 month'),
    MockPlan('Pro Mobile', 3200, '1 month'),
  ],
};

const List<String> kMockDiscos = [
  'Ikeja Electric (IKEDC)',
  'Eko Electric (EKEDC)',
  'Abuja Electric (AEDC)',
  'Ibadan Electric (IBEDC)',
  'Enugu Electric (EEDC)',
  'Port Harcourt Electric (PHED)',
  'Kano Electric (KEDCO)',
  'Jos Electric (JED)',
  'Kaduna Electric (KAEDCO)',
  'Benin Electric (BEDC)',
];

const List<MockPlan> kMockEducationProducts = [
  MockPlan('WAEC Result Checker PIN', 3900),
  MockPlan('WAEC Registration PIN', 18500),
  MockPlan('JAMB UTME PIN', 6200),
  MockPlan('JAMB Direct Entry PIN', 6200),
];

const List<MockPlan> kMockInsuranceProducts = [
  MockPlan('Third Party Motor — Private car', 15000, '1 year'),
  MockPlan('Third Party Motor — Commercial', 20000, '1 year'),
  MockPlan('Personal Accident', 5000, '1 year'),
  MockPlan('Home Cover', 9000, '1 year'),
];

class MockCountry {
  final String name;
  final String flag;
  final String dialCode;
  final String currency;
  final double rate; // ₦ per 1 unit of local currency (sample only)
  const MockCountry(this.name, this.flag, this.dialCode, this.currency, this.rate);
}

const List<MockCountry> kMockCountries = [
  MockCountry('Ghana', '🇬🇭', '+233', 'GHS', 105),
  MockCountry('Kenya', '🇰🇪', '+254', 'KES', 12),
  MockCountry('Sierra Leone', '🇸🇱', '+232', 'SLE', 70),
  MockCountry('United Kingdom', '🇬🇧', '+44', 'GBP', 2000),
  MockCountry('United States', '🇺🇸', '+1', 'USD', 1550),
  MockCountry('South Africa', '🇿🇦', '+27', 'ZAR', 85),
  MockCountry('Cameroon', '🇨🇲', '+237', 'XAF', 2.6),
];

class MockNotification {
  final String title;
  final String body;
  final Duration ago;
  final bool read;
  final String kind; // payment, wallet, promo, security
  const MockNotification(this.title, this.body, this.ago, this.read, this.kind);
}

const List<MockNotification> kMockNotifications = [
  MockNotification('Payment successful', 'Your ₦2,000 MTN airtime purchase was successful.', Duration(minutes: 25), false, 'payment'),
  MockNotification('Wallet funded', '₦50,000 has been added to your wallet.', Duration(hours: 3), false, 'wallet'),
  MockNotification('Earn more this weekend', 'Get extra commission on all data purchases until Sunday.', Duration(days: 1), true, 'promo'),
  MockNotification('New login', 'Your account was opened on a new device.', Duration(days: 2), true, 'security'),
  MockNotification('DSTV payment pending', 'We\'re confirming your DSTV Compact payment with the provider.', Duration(days: 1, hours: 6), true, 'payment'),
];

class MockReferral {
  final String name;
  final Duration joined;
  final double earned;
  final bool active;
  const MockReferral(this.name, this.joined, this.earned, this.active);
}

const List<MockReferral> kMockReferrals = [
  MockReferral('Chidi Eze', Duration(days: 3), 500, true),
  MockReferral('Fatima Bello', Duration(days: 9), 500, true),
  MockReferral('Tunde Adeyemi', Duration(days: 15), 0, false),
  MockReferral('Ngozi Obi', Duration(days: 22), 500, true),
];

/// "5 mins ago", "Yesterday", "12 Jan" — for list subtitles.
String mockTimeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hrs ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

/// "18 Jan 2026, 14:05"
String mockDateTime(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
}
