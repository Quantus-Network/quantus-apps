# Quantus desktop wallet

Desktop companion for the cold wallet app. It never holds a key: every account
is imported by scanning the address QR the cold wallet shows, and every
transaction is signed on the cold wallet through animated QR codes in both
directions. Runs on macOS, Windows and Linux.

## Run

```bash
melos bootstrap          # from the repository root, once
cd desktop-wallet
flutter run -d macos     # or -d windows / -d linux
flutter run -d macos --dart-define=RUN_ON_TESTNET=true
```

The first build compiles the SDK's Rust crate (cargokit, nightly toolchain with
`rust-src`) and zxing-cpp; expect several minutes.

## Camera

Scanning uses `camera` + `camera_desktop` for capture and `flutter_zxing` for
decoding. Frames are decoded off the UI isolate; the overlay, frame map and
collector live in `quantus_sdk` (`QrScanView`, `UrScanCollector`).

- macOS asks for camera access on first use. The usage string is in
  `macos/Runner/Info.plist`, the entitlement in `macos/Runner/*.entitlements`.
- Windows: allow desktop apps to use the camera in Settings → Privacy & security → Camera.
- Linux: build needs `libgtk-3-dev libsecret-1-dev libgstreamer1.0-dev
  libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good`; at runtime the
  user must be able to open the camera device and `gstreamer1.0-plugins-good`
  must be installed.

## UX testing without the phone

Debug builds hold a simulated cold wallet: the well-known development
account, or the first account of a mnemonic given at build time:

```bash
flutter run -d macos --dart-define=SIMULATED_SIGNER_MNEMONIC="word1 word2 ..."
```

Onboarding then offers "Use the simulated cold wallet", and the signing
dialog's scan step offers "Simulate the cold wallet's signature". The
simulated response is exactly what the phone would answer, and it goes
through the same verification and broadcast as a scanned one. Release builds
without the define hold no signer.

## Layout

- `lib/providers/` Riverpod providers on top of `package:quantus_sdk/quantus_sdk_riverpod.dart`.
- `lib/providers/controllers/` the cold-wallet signing flow and submission tracking.
- `lib/services/` the desktop camera scanner.
- `lib/ui/shell/` sidebar, page frame and keyboard shortcuts (Cmd/Ctrl+1…6).
- `lib/ui/screens/` one folder per tab plus onboarding and the sign dialog.
- `lib/l10n/app_en.arb` all user-facing strings.

## Tests

```bash
flutter test
flutter analyze --fatal-infos
```
