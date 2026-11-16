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
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../test/fakes.dart';
import 'support.dart';

const _windowSize = Size(1200, 800);
const _pixelRatio = 2.0;

Future<void> _open(
  WidgetTester tester,
  FakeWalletDevice device, {
  bool reduceMotion = false,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = _windowSize * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(buildApp(overrides: [...device.overrides, ...overrides]));
  await tester.pump();
  await tester.pump();
}

/// Decodes the pictures on screen, which a test otherwise never waits for.
Future<void> _showImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
    // The logo in the middle of a QR code, which the code waits for.
    for (final element in find.byType(QuantusQr).evaluate()) {
      await precacheImage(const AssetImage('assets/v2/uppercase_q_black_bg.png', package: 'quantus_sdk'), element);
    }
    // Vector icons load on their own; give them the time.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  // One frame to hear that the pictures are in, one to draw them.
  await tester.pump();
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

// Addresses of a real address's length, so the sheets that show one are
// drawn as they will look.
const _root = Account(
  walletIndex: 0,
  index: 0,
  name: 'Account 1',
  accountId: 'qzmN7RfQ2k8VtXc4hW9yLp3sD6aJ1bEuG5oZr8TnKw2xYv',
);
const _depositAddress = 'qzpK3wXs9DfL2mVb7NcQ8rTy4HgJ6aZe1UoBi5WnRk7tYe';
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

  _scene('receive', (tester) async {
    await _openReceive(tester, 'Account 1');
  });

  _scene('receive_encrypted', (tester) async {
    await _openReceive(tester, 'Encrypted Account');
  });
}

/// Opens the wallet, selects the account named [name] and opens its Receive.
Future<void> _openReceive(WidgetTester tester, String name) async {
  useFakeCheckphrases(
    (address) async =>
        address == _depositAddress ? 'Lantern-Copper-Meadow-Quartz-Harbor' : 'Harbor-Velvet-Signal-Mirror-Canyon',
  );
  await _open(
    tester,
    FakeWalletDevice()..store([_root, _second, _encrypted]),
    reduceMotion: true,
    overrides: [
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(() async => _depositAddress),
      ),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text(name)));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ToolbarAction, 'Receive'));
  await tester.pumpAndSettle();
}
