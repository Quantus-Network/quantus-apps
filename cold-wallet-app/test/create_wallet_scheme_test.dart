import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/set_password_screen.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class _NoBiometrics extends ColdAuthService {
  @override
  Future<bool> canUseBiometrics() async => false;
}

/// The signature-scheme choice on the create flow. New cold wallets default to
/// ML-DSA-65; ML-DSA-87 is available behind the ADVANCED disclosure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCreate(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coldAuthServiceProvider.overrideWithValue(_NoBiometrics())],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const CreateWalletScreen()),
        ),
      ),
    );
    // Let the (pure-Dart) mnemonic generation complete so the button enables.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  ColdAccount pushedAccount(WidgetTester tester) {
    final screen = tester.widget<SetPasswordScreen>(find.byType(SetPasswordScreen));
    expect(screen.accounts, hasLength(1));
    return screen.accounts.single;
  }

  testWidgets('defaults to ML-DSA-65 with the scheme choice hidden', (tester) async {
    await pumpCreate(tester);

    // The toggle lives behind ADVANCED and is not shown until expanded.
    expect(find.text('ML-DSA-87'), findsNothing);

    await tester.tap(find.text("I've written it down"));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(pushedAccount(tester).scheme, DilithiumScheme.mlDsa65);
  });

  testWidgets('creates an ML-DSA-87 wallet when chosen under ADVANCED', (tester) async {
    await pumpCreate(tester);

    await tester.ensureVisible(find.text('ADVANCED'));
    await tester.tap(find.text('ADVANCED'));
    await tester.pump();
    await tester.ensureVisible(find.text('ML-DSA-87'));
    await tester.tap(find.text('ML-DSA-87'));
    await tester.pump();

    await tester.tap(find.text("I've written it down"));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final account = pushedAccount(tester);
    expect(account.scheme, DilithiumScheme.mlDsa87);
    expect(account.derivationPath, endsWith("/0'"));
  });
}
