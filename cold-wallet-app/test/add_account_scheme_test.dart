import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';

/// The Add Account screen opens on the wallet's own scheme, and ADVANCED lets
/// each new account pick the other one; the index and label follow the choice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester, List<ColdAccount> held) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => held),
          derivedAddressProvider.overrideWith((ref, key) async => 'qzaddress'),
          checksumNameProvider.overrideWith((ref, address) async => 'check phrase'),
        ],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const AddAccountScreen()),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('an ML-DSA-87 wallet opens on 87 and can add a 65 account', (tester) async {
    await pumpScreen(tester, [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)]);

    expect(find.text('ML-DSA-65'), findsNothing);
    expect(find.text(HdWalletService.pathForIndex(1, DilithiumScheme.mlDsa87)), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);

    await tester.tap(find.text('ADVANCED'));
    await settle(tester);
    await tester.tap(find.text('ML-DSA-65'));
    await settle(tester);

    expect(find.text(HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa65)), findsOneWidget);
    // Index 0 at the other scheme would repeat "Account 1", so the label moves on.
    expect(find.text('Account 2'), findsOneWidget);
  });

  testWidgets('an ML-DSA-65 wallet opens on 65 and can add an 87 account', (tester) async {
    await pumpScreen(tester, [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa65)]);

    expect(find.text(HdWalletService.pathForIndex(1, DilithiumScheme.mlDsa65)), findsOneWidget);

    await tester.tap(find.text('ADVANCED'));
    await settle(tester);
    await tester.tap(find.text('ML-DSA-87'));
    await settle(tester);

    expect(find.text(HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa87)), findsOneWidget);
  });
}
