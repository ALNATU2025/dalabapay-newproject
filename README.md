# Dalabapay app

Flutter app for Dalabapay — wallet, bill payments, commission and referrals,
plus a staff admin console. It talks to the backend in
[newproject-backend](https://github.com/ALNATU2025/newproject-backend)
(Node.js + MongoDB). There is no sample data: everything you see comes from
the server.

## Run it

1. Start the backend (see its README). In development it uses a built-in
   **simulator** for bill payments and bank transfers, so every screen works
   without real money.
2. Run the app and tell it where the server is:

```bash
flutter pub get
# Live server on Render (the default)
flutter run
# Android emulator → backend on your own computer
flutter run --dart-define=API_URL=http://10.0.2.2:4000
# A phone on the same Wi-Fi as your computer
flutter run --dart-define=API_URL=http://192.168.1.20:4000
# Live server (the default — no flag needed)
flutter build apk --release
```

Plain `http://` is allowed only for local addresses (10.0.2.2, localhost,
127.0.0.1); real servers must use HTTPS.

### Testing without email or money
- **Codes**: while the backend has no SMTP settings, sign-up, password and
  PIN-reset codes appear in a snackbar (“Test mode: your code is …”) and in
  the server log.
- **Adding money**: in debug builds, Add Money shows *Test mode: receive
  ₦10,000*, and the one-time account dialog can simulate the transfer.
- **Simulator numbers**: a phone/recipient ending in `0000` fails (wallet
  refunded), `9999` stays pending; a meter, smartcard or JAMB profile ending
  in `000` is “not found”.
- **Admin console**: make your account a Super Admin on the server with
  `npm run make-super-admin -- you@example.com`, then log in again. It shows
  up in the side menu and in Profile.

## How it's built

```
lib/
  main.dart                    routes; sends you to login when a session ends
  core/
    api/api.dart               HTTP client: base URL, saved token, errors
    api/session.dart           the logged-in user (balance, role, KYC, PIN…)
    api/catalog.dart           cached networks, limits, recent recipients
    format.dart                dates and safe JSON readers
  ui/                          design system
    dp_tokens.dart             colours, type, radii, spacing (DPSpace), shadows
    dp_widgets.dart            buttons, fields, chips, cards, lists, nav, skeletons
    dp_cards.dart              balance card + quick actions
    dp_motion.dart             page transitions, appear/float/press animations
    dp_lottie.dart             Lottie animations with static fallbacks
    dp_responsive.dart         centred layout on tablets/desktop/web, text-scale cap
  presentation/
    widgets/payment_flow.dart  Review → PIN → success / pending / failed
    widgets/async_view.dart    loading, error and retry states
    screens/                   one folder per screen; admin/ for staff
```

Each screen file starts with a comment naming the endpoints it uses.
Money is in naira everywhere in the app; the server stores kobo.

### Login and security
- Sign up → email code → create a 6-digit payment PIN.
- The login token is kept in secure storage when “Remember me” is on. Next
  launch asks for the PIN to unlock.
- Every payment needs the PIN. Five wrong tries lock it for 30 minutes.
- If the server rejects the session (password changed, account disabled),
  the app returns to the login screen.

### Admin console
Visible only to staff. Each tool is shown according to the role
(Support, Finance, Administrator, Super Admin), and the server checks every
request again. It covers: Dashboard · Users (approve, activate,
credit/debit, PIN unlock/reset, history) · Transactions (filters, CSV
export) · Status Update · Refunds & Disputes · Fund Wallet · Self Fund ·
Verify Payments · Send Notification · Alerts · Roles · Provider Settings ·
Service Commission · Transaction Limits.

## Checks
GitHub Actions runs on every push:
- `flutter analyze`
- widget tests for the design system (`test/ui/`), which also produce the
  screenshots
- a **contract test** (`test/api_contract_test.dart`) that starts the real
  backend with MongoDB and runs every request the screens make — sign-up,
  payments for each service, history, earnings, disputes, KYC and all admin
  tools — checking the fields the screens read.

To run the contract test yourself, start the backend first, then:

```bash
BACKEND_DIR=../newproject-backend flutter test test/api_contract_test.dart \
  --dart-define=API_URL=http://localhost:4000
```

## Design system
- **Tokens** live in `lib/ui/dp_tokens.dart`: brand colours (light and dark),
  type styles, radii (`DP.rSm` … `DP.rXxl`), spacing (`DPSpace.md`, `DPSpace.h16`…)
  and elevation (`DP.shadowSm/Md/Lg`, `DP.glow(colour)`). Use them instead of
  loose numbers.
- **Responsive**: phones use the full width. On tablets, desktop and the web
  the app is centred (560 px; the admin console gets 1200 px). System text
  size is honoured up to 130 %.
- **Loading** uses shimmer skeletons (`DPSkeleton`, `DPSkeletonList`,
  `DPLoading.list()`); empty lists can use the animated empty state
  (`DPEmptyState(animated: true)`).
- **Motion** respects the phone's “reduce motion” setting everywhere.

### Animations (Lottie)
`assets/animations/` holds four small brand-coloured Lottie files:
`success`, `celebrate` (payment success), `loading` and `empty`. To use an
animation from LottieFiles instead, replace the file with the same name.
If a file is missing or broken the app shows the built-in version, so it
never breaks a screen. (Rive files can be added the same way later with the
`rive` package; none are used yet.)

### Screenshots
CI renders the design system (light, dark, tablet and animation frames) on
every push and publishes the images to the `ui-screenshots` branch, one
folder per branch — handy for reviewing UI changes without a device.

## Theme
Profile → **Appearance**: Normal, Dark or System.

## Images
Put images in `assets/images/` using the names in `IMAGES_NEEDED.md`. Any
that are missing show a matching icon.
