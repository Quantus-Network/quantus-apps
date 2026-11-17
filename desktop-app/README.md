# Quantus desktop wallet

Flutter desktop wallet for macOS, Windows and Linux. It shares wallet logic
with the mobile app through `wallet_core` and chain access through
`quantus_sdk`.

Run it from this directory:

```bash
flutter run -d macos   # or: -d windows, -d linux
```

## Approval on Linux

Before the wallet shows a recovery phrase or resets, it asks the person at
the computer to prove they own it. macOS and Windows have a system prompt for
that. On Linux the app asks for the login password itself and has PAM check
it, under its own PAM service. The service file is
`linux/packaging/pam.d/quantus-wallet`; the app's package will install it.
Until there is a package, install it by hand:

```bash
sudo install -m 644 linux/packaging/pam.d/quantus-wallet /etc/pam.d/quantus-wallet
```

Without the file, Recovery Phrase and Reset Wallet are unavailable and
Settings says what is missing. The app never falls back on another service.

`tool/pam_login_password_test.dart` checks a password through the real PAM;
CI runs it on Linux.
