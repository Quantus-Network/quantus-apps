# Patches to mobile_scanner 7.2.0

This is [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) 7.2.0 by Julian Steenbakker, under the BSD 3-Clause license in `LICENSE`, without its `example` and `test` folders. Only the desktop app uses this copy, through `dependency_overrides` in `desktop-app/pubspec.yaml` and `desktop-app/pubspec_overrides.yaml`. The phone keeps the published package.

## Commit the session's configuration when a start fails

`darwin/mobile_scanner/Sources/mobile_scanner/MobileScannerPlugin.swift`

`start` calls `beginConfiguration()`, and its two camera input failures returned without `commitConfiguration()`. Stopping that session then raises an `NSGenericException`, which ends the app. Each failure now commits first. 7.4.0 has the same two returns.

`desktop-app/test/services/qr_scan_source_test.dart` reads the Swift the app resolves, so it fails if this patch is lost.

## Report a camera that stops while running

`darwin/mobile_scanner/Sources/mobile_scanner/MobileScannerPlugin.swift`, `darwin/mobile_scanner/Sources/mobile_scanner/MobileScannerErrorCodes.swift`

The plugin observed neither `AVCaptureDevice.wasDisconnectedNotification` nor `AVCaptureSession.runtimeErrorNotification`, so a camera unplugged mid-scan left the picture frozen with nothing reported. `start` now observes both for its device and session (`observeCameraStopping`), and either one sends a `MOBILE_SCANNER_CAMERA_STOPPED` error on the event channel while the session exists. `releaseCamera` removes the observers. The desktop app reads that code as a camera that stopped (`MacQrScanSource`). 7.4.0 observes neither either.

The same test file checks this patch in the resolved Swift.

## Keep error events off the torch and zoom streams

`lib/src/method_channel/mobile_scanner_method_channel.dart`

Every event, errors included, arrives on one event channel. `barcodesStream` handles the errors, but `torchStateStream` and `zoomScaleStateStream` passed them on to the controller's listeners, which have no error handler, so each error event was also thrown twice uncaught. This was already so for `MOBILE_SCANNER_BARCODE_ERROR`. Those two streams now skip error events; the barcode stream still delivers them. 7.4.0 is the same. The real method channel test of a stopped camera in `desktop-app/test/services/qr_scan_source_test.dart` fails on an uncaught error if this is lost.
