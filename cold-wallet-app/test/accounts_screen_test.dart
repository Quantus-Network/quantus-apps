import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/account_avatar.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/accounts_screen.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';
import 'package:quantus_cold_wallet/screens/rename_account_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

import 'fakes/account_fixtures.dart';
import 'package:quantus_cold_wallet/components/cold_button.dart';
import 'package:quantus_cold_wallet/components/cold_dialog.dart';

/// An unlocked wallet holding [accounts], backed by mocked secure storage.
Future<ProviderContainer> walletWith(List<ColdAccount> accounts) async {
  FlutterSecureStorage.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      addressesProvider.overrideWith((ref) => {for (final a in ref.watch(accountsProvider)) fakeAddress(a): a}),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(walletControllerProvider.notifier)
      .createWallet(mnemonic: testMnemonic, accounts: accounts, protected: false);
  return container;
}

Future<void> pumpWithWallet(WidgetTester tester, ProviderContainer container, Widget home) async {
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: coldApp(home)));
  await tester.pumpAndSettle();
}

/// Lets a vault write finish: the cipher runs outside the test's fake clock.
Future<void> tapAndAwait(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

Future<List<String>> storedLabels() async =>
    (await VaultService().unlockWithBiometricKey()).accounts.map((a) => a.label).toList();

void main() {
  CheckphraseText.resolveOverride = (_) async => 'phrase';
  group('WalletController', () {
    test('lists accounts in the order they were added, whatever they derive from', () async {
      final container = await walletWith([two, legacy65]);
      await container.read(walletControllerProvider.notifier).addAccount(one);

      expect(container.read(accountsProvider).map((a) => a.label), ['Account 2', 'Old account', 'Account 1']);
      expect(await storedLabels(), ['Account 2', 'Old account', 'Account 1']);
    });

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
      final address = fakeAddress(two);

      await controller.removeAccount(two);
      expect(await storedLabels(), ['Account 1']);
      expect(container.read(addressesProvider).containsKey(address), isFalse);

      await controller.addAccount(two);
      expect(container.read(addressesProvider).containsKey(address), isTrue);
    });

    test('an ML-DSA-65 account added back by its template path derives the same key', () async {
      final container = await walletWith([one, legacy65]);
      final controller = container.read(walletControllerProvider.notifier);
      final address = fakeAddress(legacy65);

      await controller.removeAccount(legacy65);
      expect(container.read(addressesProvider).containsKey(address), isFalse);

      final path = legacy65.derivationPath;
      final back = ColdAccount.atPath(path, label: 'Back', scheme: ColdAccount.schemeOfPath(path)!)!;
      await controller.addAccount(back);
      final readded = container.read(addressesProvider)[address];
      expect(readded, isNotNull, reason: 'the path the dialog shows must derive the same key');
      expect(readded!.scheme, DilithiumScheme.mlDsa65);
      expect(readded.derivesSameKey(legacy65), isTrue);
    });

    test('a custom-path ML-DSA-65 account added back by its path and signature type keeps its key', () async {
      final container = await walletWith([one, custom65]);
      final controller = container.read(walletControllerProvider.notifier);
      final address = fakeAddress(custom65);

      await controller.removeAccount(custom65);
      expect(container.read(addressesProvider).containsKey(address), isFalse);

      final back = ColdAccount.atPath(custom65.derivationPath, label: 'Back', scheme: DilithiumScheme.mlDsa65)!;
      await controller.addAccount(back);
      expect(container.read(addressesProvider)[address]?.derivesSameKey(custom65), isTrue);
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

  group('Accounts screen', () {
    Future<ProviderContainer> pumpAccounts(WidgetTester tester, List<ColdAccount> accounts) async {
      final container = (await tester.runAsync(() => walletWith(accounts)))!;
      await pumpWithWallet(tester, container, const AccountsScreen());
      return container;
    }

    Future<void> openMenu(WidgetTester tester, int row) async {
      await tester.tap(find.byType(KebabButton).at(row));
      await tester.pumpAndSettle();
    }

    testWidgets('rows show initials, label and short address; a row opens the pairing screen', (tester) async {
      await pumpAccounts(tester, [one, two]);

      expect(find.byType(AccountAvatar), findsNWidgets(2));
      expect(find.text('Account 1'), findsOneWidget);
      expect(find.text('Account 2'), findsOneWidget);
      expect(find.text(shortAddress(fakeAddress(two))), findsOneWidget);
      expect(find.widgetWithText(QuantusButton, 'Add Account'), findsOneWidget);

      await tester.tap(find.text('Account 2'));
      await tester.pumpAndSettle();

      expect(tester.widget<ShowKeyScreen>(find.byType(ShowKeyScreen)).address, fakeAddress(two));
    });

    testWidgets('the kebab offers Show address, Rename and Disconnect account', (tester) async {
      await pumpAccounts(tester, [one, two]);

      await openMenu(tester, 1);

      expect(find.text('Show address'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Disconnect account'), findsOneWidget);

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(tester.widget<RenameAccountScreen>(find.byType(RenameAccountScreen)).account.label, 'Account 2');
    });

    testWidgets('Show address opens the pairing screen', (tester) async {
      await pumpAccounts(tester, [one, two]);

      await openMenu(tester, 1);
      await tester.tap(find.text('Show address'));
      await tester.pumpAndSettle();

      expect(tester.widget<ShowKeyScreen>(find.byType(ShowKeyScreen)).address, fakeAddress(two));
    });

    testWidgets('disconnects only after confirming, then says so in a toast', (tester) async {
      final container = await pumpAccounts(tester, [one, two]);

      await openMenu(tester, 1);
      await tester.tap(find.text('Disconnect account'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Account 2?'), findsOneWidget);
      expect(
        find.textContaining('Your 12 words bring it back only with the derivation path and signature type'),
        findsOneWidget,
      );
      expect(find.descendant(of: find.byType(ColdDialog), matching: find.text(two.derivationPath)), findsOneWidget);
      expect(find.descendant(of: find.byType(ColdDialog), matching: find.text('ML-DSA-87')), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(accountsProvider), hasLength(2));

      await openMenu(tester, 1);
      await tester.tap(find.text('Disconnect account'));
      await tester.pumpAndSettle();
      await tapAndAwait(tester, find.widgetWithText(ColdButton, 'Disconnect'));

      expect(container.read(accountsProvider).map((a) => a.label), ['Account 1']);
      expect(find.text('Account 2'), findsNothing);
      expect(find.text('Account 2 disconnected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the confirmation shows a custom path and its signature type to save first', (tester) async {
      await pumpAccounts(tester, [one, custom65]);

      await openMenu(tester, 1);
      await tester.tap(find.text('Disconnect account'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Elsewhere?'), findsOneWidget);
      expect(find.descendant(of: find.byType(ColdDialog), matching: find.text("m/44'/1'/0'")), findsOneWidget);
      expect(find.descendant(of: find.byType(ColdDialog), matching: find.text('ML-DSA-65')), findsOneWidget);
    });

    testWidgets('disconnecting from the pairing screen returns here with the toast', (tester) async {
      final container = await pumpAccounts(tester, [one, two]);

      await tester.tap(find.text('Account 2'));
      await tester.pumpAndSettle();
      await openMenu(tester, 0);
      await tester.tap(find.text('Disconnect account'));
      await tester.pumpAndSettle();
      await tapAndAwait(tester, find.widgetWithText(ColdButton, 'Disconnect'));

      expect(find.byType(ShowKeyScreen), findsNothing);
      expect(find.byType(AccountsScreen), findsOneWidget);
      expect(container.read(accountsProvider).map((a) => a.label), ['Account 1']);
      expect(find.text('Account 2 disconnected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the only account cannot be disconnected', (tester) async {
      final container = await pumpAccounts(tester, [one]);

      await openMenu(tester, 0);
      expect(find.textContaining('cannot be disconnected'), findsOneWidget);

      await tester.tap(find.text('Disconnect account'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Account 1?'), findsNothing);
      expect(find.text('Disconnect account'), findsOneWidget);
      expect(container.read(accountsProvider), hasLength(1));
    });

    testWidgets('Add Account opens the add screen', (tester) async {
      await pumpAccounts(tester, [one]);

      await tester.tap(find.text('Add Account'));
      await tester.pumpAndSettle();

      expect(find.byType(AddAccountScreen), findsOneWidget);
    });
  });
}
