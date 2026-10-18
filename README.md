# Dalabapay — UI/UX only

A clean copy of the Dalabapay app's screens and design system, with **all
logic and backend calls removed**. Every screen runs on sample data, so you
can click through the whole app, restyle it, or wire up a new backend.

## What's inside

```
lib/
  main.dart                  routes for every screen
  ui/                        the design system (colours, type, buttons,
                             fields, chips, cards, keypad, review/success
                             panels, motion) — copied unchanged
  core/theme/app_theme.dart  app-wide theme (Inter font)
  mock/mock_data.dart        ALL sample data (user, balances, transactions,
                             plans, providers, notifications…)
  presentation/
    widgets/
      payment_flow.dart      Review payment → PIN → Payment successful
      transaction_widgets.dart  transaction rows + receipt sheet
    screens/                 one folder per screen
```

### Screens
Splash · Onboarding · Login · Sign up (+ email code) · Forgot password ·
OTP · Reset password · PIN setup / PIN login / PIN lock · Change PIN ·
Change password · Home (dashboard, drawer, banners) · All Services ·
Pay Bills · Airtime · Data · Electricity · Cable TV · Education ·
Insurance · International airtime · Add Money · Send Money ·
My Wallet / Transactions · Commission & earnings · Refer & earn ·
Notifications · Profile / Security · KYC · My Disputes ·
Transaction validation · Help & support

## How "fake" actions behave
- **Login / PIN / biometrics** – any input works and opens Home.
- **Verify meter / smartcard / profile / recipient** – shows a sample
  customer after a short delay.
- **Pay** – shows the Review screen; any 4–6 digit PIN "pays" and shows
  Payment Successful with a sample reference.
- **Share, export, contacts, image upload, WhatsApp/email** – show a short
  "not set up in this UI build" message.

## Removed
API/payment/auth/socket/notification services, providers, secure storage,
shared preferences, Firebase (Android `google-services.json`, Gradle plugin
and manifest entries), the cleartext network config for the old backend, the
native contacts channel, and the **admin** screens.

## Run it
```
flutter pub get
flutter run
```
Only two packages are used: `google_fonts` and `cupertino_icons`.

The Android app id is `com.dalabapay.newproject` so it installs next to the
live app. Change it in `android/app/build.gradle.kts` if you want.

## Images
Drop your images into `assets/images/` using the names in `IMAGES_NEEDED.md`
(logo, onboarding art, service icons, provider logos, banners). Until then
each one shows a matching icon.

## Wiring a backend later
Search for `mock_data.dart` imports — those are the places that need real
data. `showReviewAndPay` in `payment_flow.dart` is the single place where a
payment would be sent.
