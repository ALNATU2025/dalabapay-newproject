// lib/main.dart
// Dalabapay app. Talks to the DalabaPay backend (newproject-backend); set
// the server with --dart-define=API_URL=https://api.example.com
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/api/api.dart';
import 'core/api/session.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'ui/ui.dart';
import 'presentation/screens/admin/admin_all_transactions_page.dart';
import 'presentation/screens/admin/admin_control_page.dart';
import 'presentation/screens/admin/admin_dashboard_screen.dart';
import 'presentation/screens/admin/admin_fund_wallet_page.dart';
import 'presentation/screens/admin/admin_notifications_page.dart';
import 'presentation/screens/admin/admin_refund_system_page.dart';
import 'presentation/screens/admin/admin_self_fund_page.dart';
import 'presentation/screens/admin/admin_send_notification_page.dart';
import 'presentation/screens/admin/admin_sl_funding_page.dart';
import 'presentation/screens/admin/admin_service_commission_page.dart';
import 'presentation/screens/admin/admin_transaction_limits_page.dart';
import 'presentation/screens/admin/admin_transaction_status_page.dart';
import 'presentation/screens/admin/admin_users_page.dart';
import 'presentation/screens/admin/admin_verify_payment_page.dart';
import 'presentation/screens/admin/vtpass_settings_dashboard.dart';
import 'presentation/screens/airtime/airtime_screen.dart';
import 'presentation/screens/auth/change_password_screen.dart';
import 'presentation/screens/auth/change_pin_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/otp_verification_screen.dart';
import 'presentation/screens/auth/pin_lock_screen.dart';
import 'presentation/screens/auth/pin_login_screen.dart';
import 'presentation/screens/auth/pin_setup_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/reset_password_screen.dart';
import 'presentation/screens/cabletv/cabletv_screen.dart';
import 'presentation/screens/commission/commission_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/disputes/user_disputes_page.dart';
import 'presentation/screens/education/education_screen.dart';
import 'presentation/screens/electricity/electricity_screen.dart';
import 'presentation/screens/help/help_screen.dart';
import 'presentation/screens/insurance/insurance_screen.dart';
import 'presentation/screens/international_airtime/international_airtime_screen.dart';
import 'presentation/screens/internet/internet_screen.dart';
import 'presentation/screens/kyc/kyc_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/referral/referral_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/sierra_leone/sl_add_money_screen.dart';
import 'presentation/screens/sierra_leone/sl_cable_screen.dart';
import 'presentation/screens/sierra_leone/sl_electricity_screen.dart';
import 'presentation/screens/sierra_leone/sl_topup_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/transactions/transactions_screen.dart';
import 'presentation/screens/validation/transaction_validation_page.dart';
import 'presentation/screens/wallet/send_money_screen.dart';
import 'presentation/screens/wallet/wallet_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Phones stay upright; tablets and desktops may rotate (the layout is
  // centred there, see DPResponsiveFrame).
  final views = WidgetsBinding.instance.platformDispatcher.views;
  final phone = views.isEmpty ||
      views.first.physicalSize.shortestSide / views.first.devicePixelRatio <
          DPBreakpoints.medium;
  if (phone) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  ThemeController.instance.apply();
  // Saved login rejected by the server (expired, password changed,
  // account deactivated): back to the login screen.
  Api.instance.onUnauthorized = () {
    Session.instance.logout();
    final nav = DalabapayApp.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
    final ctx = DalabapayApp.navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        const SnackBar(content: Text('Your session has ended. Please log in again.')),
      );
    }
  };
  runApp(const DalabapayApp());
}

class DalabapayApp extends StatelessWidget {
  const DalabapayApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Every screen, by route name.
  static final Map<String, WidgetBuilder> routes = {
    '/': (_) => const SplashScreen(),
    '/onboarding': (_) => const OnboardingScreen(),
    '/login': (_) => const LoginScreen(),
    '/register': (_) => const RegisterScreen(),
    '/forgot-password': (_) => const ForgotPasswordScreen(),
    '/reset-password': (_) => const ResetPasswordScreen(),
    '/pin-setup': (_) => const PinSetupScreen(),
    '/pin-login': (_) => const PinLoginScreen(),
    '/pin-lock': (_) => const PinLockScreen(),
    '/change-pin': (_) => const ChangePinScreen(),
    '/change-password': (_) => const ChangePasswordScreen(),
    '/dashboard': (_) => const DashboardScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/kyc': (_) => const KYCScreen(),
    '/notifications': (_) => const NotificationsScreen(),
    '/transactions': (_) => const TransactionsScreen(),
    '/user-disputes': (_) => const UserDisputesPage(),
    '/help': (_) => const HelpScreen(),
    '/transaction-validation': (_) => const TransactionValidationPage(),
    '/airtime': (_) => const AirtimeScreen(),
    '/data': (_) => const InternetScreen(),
    '/internet': (_) => const InternetScreen(),
    '/electricity': (_) => const ElectricityScreen(),
    '/cable': (_) => const CableTvScreen(),
    '/cabletv': (_) => const CableTvScreen(),
    '/education': (_) => const EducationScreen(),
    '/international-airtime': (_) => const InternationalAirtimeScreen(),
    '/insurance': (_) => const InsuranceScreen(),
    '/commission': (_) => const CommissionScreen(),
    '/referral': (_) => const ReferralScreen(),
    // Sierra Leone accounts add money by mobile money / bank ("I've paid").
    '/wallet': (_) => Session.instance.isSierraLeone
        ? const SlAddMoneyScreen()
        : const WalletTopUpScreen(),
    // Sierra Leone services (Leones)
    '/sl/airtime': (_) => const SlTopUpScreen(),
    '/sl/data': (_) => const SlTopUpScreen(data: true),
    '/sl/electricity': (_) => const SlElectricityScreen(),
    '/sl/cable': (_) => const SlCableScreen(),
    '/sl/add-money': (_) => const SlAddMoneyScreen(),
    '/send-money': (_) => const SendMoneyScreen(),
    // Admin console (staff roles only; the server checks permissions)
    '/admin': (_) => const AdminDashboardScreen(),
    '/admin/users': (_) => const AdminUsersPage(),
    '/admin/transactions': (_) => const AdminAllTransactionsPage(),
    '/admin/status': (_) => const AdminTransactionStatusPage(),
    '/admin/refunds': (_) => const AdminRefundSystemPage(),
    '/admin/fund-wallet': (_) => const AdminFundWalletPage(),
    '/admin/self-fund': (_) => const AdminSelfFundPage(),
    '/admin/verify': (_) => const AdminVerifyPaymentPage(),
    '/admin/send-notification': (_) => const AdminSendNotificationPage(),
    '/admin/alerts': (_) => const AdminNotificationsPage(),
    '/admin/control': (_) => const AdminControlPage(),
    '/admin/vtpass': (_) => const VtpassSettingsDashboard(),
    '/admin/commission': (_) => const AdminServiceCommissionPage(),
    '/admin/limits': (_) => const AdminTransactionLimitsPage(),
    '/admin/sl-funding': (_) => const AdminSlFundingPage(),
  };

  @override
  Widget build(BuildContext context) {
    // Rebuilds with the new colours whenever the theme is switched in
    // Profile → Appearance.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Dalabapay',
      debugShowCheckedModeBanner: false,
      // AppTheme.current already reflects light/dark, so one theme is used.
      theme: AppTheme.current,
      themeMode: ThemeMode.light,
      navigatorObservers: [DPRouteWatcher.instance],
      builder: (context, child) => ThemeRefresher(
        child: DPResponsiveFrame(child: child ?? const SizedBox.shrink()),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/otp-verification') {
          final email = settings.arguments is String
              ? settings.arguments as String
              : '';
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => OtpVerificationScreen(email: email),
          );
        }
        final builder = routes[settings.name] ?? routes['/dashboard']!;
        return MaterialPageRoute(settings: settings, builder: builder);
      },
      ),
    );
  }
}
