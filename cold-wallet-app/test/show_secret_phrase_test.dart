import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_cold_wallet/screens/show_secret_phrase_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

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
  testWidgets('the secret phrase is gated by the password and starts hidden', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container
          .read(walletControllerProvider.notifier)
          .createWallet(
            mnemonic: _mnemonic,
            password: 'alpha',
            enableBiometric: false,
            accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy)],
          ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const SettingsScreen()),
        ),
      ),
    );

    await tester.tap(find.text('Show secret phrase'));
    await tester.pumpAndSettle();
    expect(find.text('Enter password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Incorrect password'));
    expect(find.byType(ShowSecretPhraseScreen), findsNothing);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.tap(find.text('Continue'));
    await tester.pump();
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

  testWidgets('locking mid-view clears and re-hides the phrase', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(walletControllerProvider.notifier);
    await tester.runAsync(
      () => controller.createWallet(
        mnemonic: _mnemonic,
        password: 'alpha',
        enableBiometric: false,
        accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy)],
      ),
    );

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
