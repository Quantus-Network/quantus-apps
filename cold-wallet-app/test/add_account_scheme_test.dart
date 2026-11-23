import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/scheme_picker.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';

/// The Add Account screen names the next account and, under ADVANCED, opens on
/// ML-DSA-87; picking ML-DSA-65 moves the index with it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CheckphraseText.resolveOverride = (_) async => 'check phrase';

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
        ],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const AddAccountScreen()),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('ML-DSA-65'), findsNothing);
    await tester.tap(find.text('ADVANCED'));
    await settle(tester);
  }

  /// The path field, once the name field sits above it.
  Finder pathField() => find.descendant(of: find.byType(QuantusTextField).last, matching: find.byType(TextField));

  QuantusButton createButton(WidgetTester tester) =>
      tester.widget<QuantusButton>(find.widgetWithText(QuantusButton, 'Create Account'));

  testWidgets('opens on the next free name, and refuses a taken or empty one', (tester) async {
    await pumpScreen(tester, [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)]);

    expect(find.text('Name this account'), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);
    expect(createButton(tester).isDisabled, isFalse);

    await tester.enterText(find.byType(TextField).first, 'Account 1');
    await settle(tester);
    expect(find.text('Another account is already named Account 1.'), findsOneWidget);
    expect(createButton(tester).isDisabled, isTrue);

    await tester.enterText(find.byType(TextField).first, ' ');
    await settle(tester);
    expect(createButton(tester).isDisabled, isTrue);
  });

  testWidgets('an ML-DSA-87 wallet opens on 87 and can add a 65 account', (tester) async {
    await pumpScreen(tester, [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)]);

    expect(find.text('ML-DSA-65'), findsOneWidget);
    expect(find.text(HdWalletService.pathForIndex(1, DilithiumScheme.mlDsa87)), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);

    await tester.ensureVisible(find.text('ML-DSA-65'));
    await tester.tap(find.text('ML-DSA-65'));
    await settle(tester);

    expect(find.text(HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa65)), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);
  });

  testWidgets('an ML-DSA-65 wallet still opens on 87 and can add another 65 account', (tester) async {
    await pumpScreen(tester, [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa65)]);

    expect(find.text(HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa87)), findsOneWidget);

    await tester.ensureVisible(find.text('ML-DSA-65'));
    await tester.tap(find.text('ML-DSA-65'));
    await settle(tester);

    expect(find.text(HdWalletService.pathForIndex(1, DilithiumScheme.mlDsa65)), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);
  });

  testWidgets('a typed path ending in 1\' snaps the picker to ML-DSA-65', (tester) async {
    await pumpScreen(tester, [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)]);

    await tester.ensureVisible(find.text('Derivation path'));
    await tester.tap(find.text('Derivation path'));
    await settle(tester);
    await tester.enterText(pathField(), "m/44'/1'/1'");
    await settle(tester);

    expect(tester.widget<SchemePicker>(find.byType(SchemePicker)).value, DilithiumScheme.mlDsa65);
    expect(find.text("m/44'/1'/1'"), findsWidgets);
  });

  testWidgets('ML-DSA-65 picked after typing a path ending in 0\' keeps the path', (tester) async {
    await pumpScreen(tester, [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)]);

    await tester.ensureVisible(find.text('Derivation path'));
    await tester.tap(find.text('Derivation path'));
    await settle(tester);
    await tester.enterText(pathField(), "m/44'/1'/0'");
    await settle(tester);
    expect(tester.widget<SchemePicker>(find.byType(SchemePicker)).value, DilithiumScheme.mlDsa87);

    await tester.ensureVisible(find.text('ML-DSA-65'));
    await tester.tap(find.text('ML-DSA-65'));
    await settle(tester);

    expect(tester.widget<SchemePicker>(find.byType(SchemePicker)).value, DilithiumScheme.mlDsa65);
    expect(tester.widget<TextField>(pathField()).controller!.text, "m/44'/1'/0'");
  });
}
