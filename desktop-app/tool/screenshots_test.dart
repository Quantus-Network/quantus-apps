// Draws the app's pages to PNG files with the real fonts, so the Flutter side
// of the UI can be looked at without running the app. The native window
// chrome (the traffic lights) is not in the pictures.
//
//   flutter test tool/screenshots_test.dart --update-goldens
//
// The pictures land in build/screenshots/.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../test/fakes.dart';
import 'support.dart';

const _windowSize = Size(1200, 800);
const _pixelRatio = 2.0;

Future<void> _open(WidgetTester tester, FakeWalletDevice device, {bool reduceMotion = false}) async {
  tester.view.physicalSize = _windowSize * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(buildApp(overrides: device.overrides));
  await tester.pump();
  await tester.pump();
}

/// Decodes the pictures on screen, which a test otherwise never waits for.
Future<void> _showImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
    // Vector icons load on their own; give them the time.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

Future<void> _snap(WidgetTester tester, String name) async {
  await _showImages(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screenshots/$name.png'));
}

void _scene(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    WidgetsApp.debugAllowBannerOverride = false;
    try {
      await body(tester);
      await _snap(tester, name);
    } finally {
      debugDisableShadows = true;
      WidgetsApp.debugAllowBannerOverride = true;
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

const _root = Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'qzRoot');
const _second = Account(walletIndex: 0, index: 1, name: 'Savings', accountId: 'qzSavings');
const _encrypted = Account(
  walletIndex: 0,
  index: AppConstants.encryptedAccountIndex,
  name: 'Encrypted Account',
  accountId: 'qzEncrypted0',
  accountType: AccountType.encrypted,
);

void main() {
  // Outside the tests: a test's clock is faked, and loading would never end.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  _scene('boot_intro', (tester) async {
    await _open(tester, FakeWalletDevice()..storage.bools.clear());
    await tester.pump(const Duration(milliseconds: 1250));
  });

  _scene('welcome', (tester) async {
    await _open(tester, FakeWalletDevice());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(820, 300));
    for (var i = 0; i < 240; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  _scene('import_wallet', (tester) async {
    await _open(tester, FakeWalletDevice(), reduceMotion: true);
    await tester.tap(find.widgetWithText(QuantusButton, 'Import Wallet'));
    await tester.pumpAndSettle();
  });

  _scene('wallet_created', (tester) async {
    await _open(tester, FakeWalletDevice(), reduceMotion: true);
    await tester.tap(find.widgetWithText(QuantusButton, 'Create New Wallet'));
    await tester.pumpAndSettle();
  });

  _scene('shell', (tester) async {
    await _open(tester, FakeWalletDevice()..store([_root, _second, _encrypted]), reduceMotion: true);
    await tester.pumpAndSettle();
  });
}
