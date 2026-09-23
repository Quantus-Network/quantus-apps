import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/accounts_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

import 'multi_account_test.dart' show mnemonic;

final one = ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy);
final two = ColdAccount(label: 'Account 2', index: 1, scheme: DilithiumSchemeExtension.legacy);

Future<ProviderContainer> walletWith(List<ColdAccount> accounts) async {
  FlutterSecureStorage.setMockInitialValues({});
  // Key derivation needs the native library, which unit tests do not load, so
  // each account stands in for its address by its derivation path.
  final container = ProviderContainer(
    overrides: [
      addressesProvider.overrideWith((ref) => {for (final a in ref.watch(accountsProvider)) a.derivationPath: a}),
      checksumNameProvider.overrideWith((ref, address) async => 'phrase'),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(walletControllerProvider.notifier)
      .createWallet(mnemonic: mnemonic, password: 'alpha', enableBiometric: false, accounts: accounts);
  return container;
}

Future<void> pumpAccounts(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => Theme(data: AppTheme.darkTheme(context), child: child!),
        home: const AccountsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openEditor(WidgetTester tester, int row) async {
  await tester.tap(find.byIcon(Icons.edit_outlined).at(row));
  await tester.pumpAndSettle();
}

Future<List<String>> storedLabels() async =>
    (await VaultService().unlockWithPassword('alpha')).accounts.map((a) => a.label).toList();

void main() {
  group('WalletController', () {
    test('renames an account and keeps its derivation', () async {
      final container = await walletWith([one, two]);
      await container.read(walletControllerProvider.notifier).renameAccount(two, 'Savings');

      expect(container.read(accountsProvider).map((a) => a.label), ['Account 1', 'Savings']);
      expect(container.read(accountsProvider).last.derivationPath, two.derivationPath);
      expect(await storedLabels(), ['Account 1', 'Savings']);
    });

    test('removes an account, and adding its path again brings it back', () async {
      final container = await walletWith([one, two]);
      final controller = container.read(walletControllerProvider.notifier);
      final address = two.derivationPath;

      await controller.removeAccount(two);
      expect(await storedLabels(), ['Account 1']);
      expect(container.read(addressesProvider).containsKey(address), isFalse);

      await controller.addAccount(two);
      expect(container.read(addressesProvider).containsKey(address), isTrue);
    });

    test('refuses to remove the last account', () async {
      final container = await walletWith([one]);
      expect(() => container.read(walletControllerProvider.notifier).removeAccount(one), throwsStateError);
    });

    test('refuses to change an account the wallet does not hold', () async {
      final container = await walletWith([one]);
      final controller = container.read(walletControllerProvider.notifier);
      expect(() => controller.renameAccount(two, 'x'), throwsStateError);
      expect(() => controller.removeAccount(two), throwsStateError);
    });
  });

  group('the edit screen', () {
    testWidgets('renames from the pencil icon', (tester) async {
      final container = (await tester.runAsync(() => walletWith([one, two])))!;
      await pumpAccounts(tester, container);

      await openEditor(tester, 1);
      await tester.enterText(find.byType(TextField), 'My special account');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('My special account'), findsOneWidget);
      expect(find.text('Account 2'), findsNothing);
    });

    testWidgets('does not save a name another account already has', (tester) async {
      final container = (await tester.runAsync(() => walletWith([one, two])))!;
      await pumpAccounts(tester, container);

      await openEditor(tester, 1);
      await tester.enterText(find.byType(TextField), 'Account 1');
      await tester.pump();

      expect(find.text('Another account is already named Account 1.'), findsOneWidget);
      expect(tester.widget<QuantusButton>(find.widgetWithText(QuantusButton, 'Save')).isDisabled, isTrue);
    });

    testWidgets('disconnects only after confirming, and says how to add it back', (tester) async {
      final container = (await tester.runAsync(() => walletWith([one, two])))!;
      await pumpAccounts(tester, container);

      await openEditor(tester, 1);
      await tester.tap(find.text('Disconnect account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('adding an account with the same derivation path'), findsOneWidget);
      expect(find.textContaining(two.derivationPath), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(accountsProvider), hasLength(2));

      await tester.tap(find.text('Disconnect account'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(QuantusButton, 'Disconnect'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(container.read(accountsProvider).map((a) => a.label), ['Account 1']);
      expect(find.text('Account 2'), findsNothing);
    });

    testWidgets('does not offer to disconnect the only account', (tester) async {
      final container = (await tester.runAsync(() => walletWith([one])))!;
      await pumpAccounts(tester, container);

      await openEditor(tester, 0);

      expect(find.text('Disconnect account'), findsNothing);
      expect(find.textContaining('cannot be disconnected'), findsOneWidget);
    });
  });
}
