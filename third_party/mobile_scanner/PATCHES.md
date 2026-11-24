# Patches to mobile_scanner 7.2.0

This is [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) 7.2.0 by Julian Steenbakker, under the BSD 3-Clause license in `LICENSE`, without its `example` and `test` folders. Only the desktop app uses this copy, through `dependency_overrides` in `desktop-app/pubspec.yaml` and `desktop-app/pubspec_overrides.yaml`. The phone keeps the published package.

## Commit the session's configuration when a start fails

`darwin/mobile_scanner/Sources/mobile_scanner/MobileScannerPlugin.swift`

`start` calls `beginConfiguration()`, and its two camera input failures returned without `commitConfiguration()`. Stopping that session then raises an `NSGenericException`, which ends the app. Each failure now commits first. 7.4.0 has the same two returns.

`desktop-app/test/services/qr_scan_source_test.dart` reads the Swift the app resolves, so it fails if this patch is lost.
