import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_cold_wallet/screens/show_secret_phrase_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/wallet_fakes.dart';

class _PresenceController extends WalletController {
  _PresenceController({required this.confirms});

  final bool confirms;
  int checks = 0;

  @override
  WalletState build() =>
      const WalletState(status: WalletStatus.unlocked, mnemonic: testMnemonic, biometricEnabled: true);

  @override
  Future<bool> confirmPresence() async {
    checks++;
    return confirms;
  }
}

/// The Argon2id unlock runs on the real event loop, which the fake-async test
/// clock cannot drive (and the in-flight spinner never settles); poll with
/// real waits until the expected widget appears.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('not found: $finder');
}

void main() {
  Future<void> pumpSettings(WidgetTester tester, ProviderContainer container) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the secret phrase is gated by a fresh device-key read and starts hidden', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer(overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth())]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await awaitInit(container);
      await container
          .read(walletControllerProvider.notifier)
          .createWallet(mnemonic: testMnemonic, accounts: testAccounts, protected: true);
    });
    await pumpSettings(tester, container);

    await tester.tap(find.text('Show secret phrase'));
    await _pumpUntilFound(tester, find.byType(ShowSecretPhraseScreen));
    await tester.pumpAndSettle();

    expect(find.text('Tap to reveal'), findsOneWidget);
    expect(find.text('abandon'), findsNothing);

    await tester.tap(find.text('Tap to reveal'));
    await tester.pump();
    expect(find.text('abandon'), findsNWidgets(11));
    expect(find.text('about'), findsOneWidget);

    await tester.tap(find.text('Tap to hide'));
    await tester.pump();
    expect(find.text('abandon'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(ShowSecretPhraseScreen), findsNothing);
  });

  testWidgets('a dismissed prompt keeps the phrase closed', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final controller = _PresenceController(confirms: false);
    final container = ProviderContainer(overrides: [walletControllerProvider.overrideWith(() => controller)]);
    addTearDown(container.dispose);
    await pumpSettings(tester, container);

    await tester.tap(find.text('Show secret phrase'));
    await tester.pumpAndSettle();

    expect(controller.checks, 1);
    expect(find.byType(ShowSecretPhraseScreen), findsNothing);
    expect(find.text('Could not confirm it is you.'), findsOneWidget);
    // Let the toast time out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('locking mid-view clears and re-hides the phrase', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final controller = _PresenceController(confirms: true);
    final container = ProviderContainer(overrides: [walletControllerProvider.overrideWith(() => controller)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const ShowSecretPhraseScreen()),
        ),
      ),
    );

    await tester.tap(find.text('Tap to reveal'));
    await tester.pump();
    expect(find.text('abandon'), findsNWidgets(11));

    controller.lock();
    await tester.pump();
    expect(find.text('abandon'), findsNothing);
    expect(find.text('Tap to reveal'), findsOneWidget);
  });
}
