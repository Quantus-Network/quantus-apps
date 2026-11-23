import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/unlock_method_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'fakes/wallet_fakes.dart';

/// The signature-scheme choice on the create flow. New cold wallets default to
/// ML-DSA-87; ML-DSA-65 sits under ADVANCED on the same screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCreate(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth(biometrics: true))],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const CreateWalletScreen()),
        ),
      ),
    );
    // Let the (pure-Dart) mnemonic generation complete so the button enables.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<ColdAccount> pushedAccount(WidgetTester tester) async {
    await tester.tap(find.text("I've written it down"));
    await tester.pumpAndSettle();
    final screen = tester.widget<UnlockMethodScreen>(find.byType(UnlockMethodScreen));
    expect(screen.accounts, hasLength(1));
    return screen.accounts.single;
  }

  testWidgets('defaults to ML-DSA-87 with the scheme choice under ADVANCED', (tester) async {
    await pumpCreate(tester);

    expect(find.text('ML-DSA-65'), findsNothing);
    await tester.ensureVisible(find.text('ADVANCED'));
    await tester.tap(find.text('ADVANCED'));
    await tester.pump();
    expect(find.text('ML-DSA-65'), findsOneWidget);
    expect(find.text('ML-DSA-87'), findsOneWidget);

    final account = await pushedAccount(tester);
    expect(account.label, 'Main key');
    expect(account.scheme, DilithiumScheme.mlDsa87);
    expect(account.derivationPath, endsWith("/0'"));
  });

  testWidgets('creates an ML-DSA-65 wallet when chosen', (tester) async {
    await pumpCreate(tester);

    await tester.ensureVisible(find.text('ADVANCED'));
    await tester.tap(find.text('ADVANCED'));
    await tester.pump();
    await tester.ensureVisible(find.text('ML-DSA-65'));
    await tester.tap(find.text('ML-DSA-65'));
    await tester.pump();

    final account = await pushedAccount(tester);
    expect(account.scheme, DilithiumScheme.mlDsa65);
    expect(account.derivationPath, endsWith("/1'"));
  });
}
