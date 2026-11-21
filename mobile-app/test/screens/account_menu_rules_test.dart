import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/account_list_row.dart';
import 'package:resonance_network_wallet/v2/components/multisig_signer_list_tile.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/edit_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/wallet_name_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../extensions.dart';
import '../fakes.dart';

/// Pins what the phone's account menus offer and what their actions store,
/// before these rules move to wallet_core. Everything runs against the real
/// SettingsService over mocked storage, so each pin checks what is stored.
void main() {
  Account account(int walletIndex, int index, {AccountType type = AccountType.local}) => Account(
    walletIndex: walletIndex,
    index: index,
    name: 'W${walletIndex}A$index',
    accountId: 'qzw${walletIndex}a$index${'x' * 40}',
    accountType: type,
    scheme: type == AccountType.local ? DilithiumSchemeExtension.current : null,
    derivationPath: type == AccountType.local
        ? HdWalletService.pathForIndex(index, DilithiumSchemeExtension.current)
        : null,
  );

  final a1 = account(0, 1);
  final a2 = account(0, 2);
  final encrypted = account(0, 0, type: AccountType.encrypted);
  final keystone = account(1, 0, type: AccountType.keystone);
  final second = account(3, 0);
  final outsider = 'qzoutsider${'x' * 40}';

  MultisigAccount multisig({String? creator}) => MultisigAccount(
    name: 'Msig',
    accountId: 'qzmsig${'x' * 40}',
    signers: [a1.accountId, outsider, a2.accountId],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: a1.accountId,
    creator: creator,
  );

  setUpAll(() => CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help');
  tearDownAll(() => CheckphraseText.resolveOverride = null);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await SettingsService().initialize();
  });

  Future<void> seed(List<Account> accounts, {List<MultisigAccount> multisigs = const [], Account? active}) async {
    final settings = SettingsService();
    await settings.saveAccounts(accounts);
    for (final m in multisigs) {
      await settings.addMultisigAccount(m);
    }
    await settings.setActiveAccount(RegularAccount(active ?? accounts.first));
    await settings.setMnemonic('wallet zero words', 0);
    await settings.setMnemonic('wallet three words', 3);
  }

  Future<List<Account>> storedAccounts() => SettingsService().getAccounts();

  Future<void> pumpAndOpen(WidgetTester tester) async {
    final config = RemoteConfigModel.fromJson({'enableEncryptedAccount': false});
    await tester.pumpApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => openAccountsScreen(context), child: const Text('open')),
          ),
        ),
      ),
      overrides: [
        balanceProviderFamily.overrideWith((ref, accountId) async => BigInt.from(10).pow(15)),
        encryptedBalanceProvider.overrideWith((ref, walletIndex) => AsyncValue.data(BigInt.zero)),
        remoteConfigProvider.overrideWith(
          (ref) => RemoteConfigNotifier(FakeRemoteConfigService(config, remote: config)),
        ),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(AccountsScreen, skipOffstage: false))).read(l10nProvider);

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openMenuOf(WidgetTester tester, String name) async {
    final row = find.ancestor(of: find.text(name), matching: find.byType(AccountListRow));
    await tapVisible(tester, find.descendant(of: row, matching: find.byType(KebabButton)));
  }

  /// Expands the collapsed wallet whose heading reads [heading].
  Future<void> expandWallet(WidgetTester tester, String heading) => tapVisible(tester, find.text(heading));

  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.pumpAndSettle();
  }

  group('the account menu offers', () {
    testWidgets('address, rename, recovery phrase and disconnect for a local account with siblings', (tester) async {
      await seed([a1, a2]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, a1.name);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.accountMenuShowAddress), findsOneWidget);
      expect(find.text(l10n.accountMenuRename), findsOneWidget);
      expect(find.text(l10n.accountMenuShowRecoveryPhrase), findsOneWidget);
      expect(find.text(l10n.accountMenuDisconnectAccount), findsOneWidget);
      expect(find.text(l10n.accountMenuInnerHash), findsNothing);
    });

    testWidgets('no disconnect for the last local account of wallet 1, an encrypted sibling aside', (tester) async {
      await seed([a1, encrypted]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, a1.name);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.accountMenuShowAddress), findsOneWidget);
      expect(find.text(l10n.accountMenuRename), findsOneWidget);
      expect(find.text(l10n.accountMenuShowRecoveryPhrase), findsOneWidget);
      expect(find.text(l10n.accountMenuDisconnectAccount), findsNothing);
    });

    testWidgets('only the inner hash for an encrypted account', (tester) async {
      await seed([a1, a2, encrypted]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, encrypted.name);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.accountMenuInnerHash), findsOneWidget);
      expect(find.text(l10n.accountMenuShowAddress), findsNothing);
      expect(find.text(l10n.accountMenuRename), findsNothing);
      expect(find.text(l10n.accountMenuShowRecoveryPhrase), findsNothing);
      expect(find.text(l10n.accountMenuDisconnectAccount), findsNothing);
    });

    testWidgets('address, rename and disconnect for the only account of a Keystone wallet', (tester) async {
      await seed([a1, keystone]);
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      await expandWallet(tester, l10n.accountsSheetKeystoneWallet(1));
      await openMenuOf(tester, keystone.name);

      expect(find.text(l10n.accountMenuShowAddress), findsOneWidget);
      expect(find.text(l10n.accountMenuRename), findsOneWidget);
      expect(find.text(l10n.accountMenuDisconnectAccount), findsOneWidget);
      expect(find.text(l10n.accountMenuShowRecoveryPhrase), findsNothing);
    });

    testWidgets('address, rename, multisig details and disconnect for a multisig', (tester) async {
      await seed([a1, a2], multisigs: [multisig()]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, 'Msig');
      final l10n = l10nOf(tester);

      expect(find.text(l10n.accountMenuShowAddress), findsOneWidget);
      expect(find.text(l10n.accountMenuRename), findsOneWidget);
      expect(find.text(l10n.multisigAccountMenuDetails), findsOneWidget);
      expect(find.text(l10n.accountMenuDisconnectAccount), findsOneWidget);
      expect(find.text(l10n.accountMenuShowRecoveryPhrase), findsNothing);
    });

    testWidgets('only rename for a wallet heading', (tester) async {
      await seed([a1, a2]);
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      await tapVisible(tester, find.text(l10n.accountsSheetWallet(1)));

      expect(find.text(l10n.accountMenuRename), findsOneWidget);
      expect(find.text(l10n.accountMenuDisconnectAccount), findsNothing);
      expect(find.text(l10n.accountMenuShowAddress), findsNothing);
    });
  });

  group('disconnect', () {
    testWidgets('a local account with a sibling in its wallet: one confirm, then only it is removed', (tester) async {
      await seed([a1, a2]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, a2.name);
      final l10n = l10nOf(tester);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectAccount));

      expect(find.text(l10n.accountMenuDisconnectAccountTitle), findsOneWidget);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnect));

      expect((await storedAccounts()).map((a) => a.accountId), [a1.accountId]);
      expect(await SettingsService().getMnemonic(0), 'wallet zero words');
    });

    testWidgets('the last account of a second software wallet: two confirms, then the whole wallet goes', (
      tester,
    ) async {
      await seed([a1, keystone, second]);
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      // Stored at index 3 with a Keystone wallet at 1, it is the second software wallet.
      await expandWallet(tester, l10n.accountsSheetWallet(2));
      await openMenuOf(tester, second.name);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectAccount));

      expect(find.text(l10n.accountMenuDisconnectWalletTitle(2)), findsOneWidget);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectWalletConfirm));
      expect(find.text(l10n.accountMenuDeleteWalletTitle), findsOneWidget);
      await tapVisible(tester, find.text(l10n.accountMenuDeleteWalletConfirm));

      expect((await storedAccounts()).map((a) => a.accountId), [a1.accountId, keystone.accountId]);
      expect(await SettingsService().getMnemonic(3), isNull);
      expect(await SettingsService().getMnemonic(0), 'wallet zero words');
    });

    testWidgets('cancelling the first wallet confirm removes nothing', (tester) async {
      await seed([a1, keystone, second]);
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      await expandWallet(tester, l10n.accountsSheetWallet(2));
      await openMenuOf(tester, second.name);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectAccount));
      await tapVisible(tester, find.text(l10n.commonCancel));

      expect(find.text(l10n.accountMenuDeleteWalletTitle), findsNothing);
      expect(await storedAccounts(), hasLength(3));
      expect(await SettingsService().getMnemonic(3), 'wallet three words');
    });

    testWidgets('cancelling the delete confirm removes nothing', (tester) async {
      await seed([a1, keystone, second]);
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      await expandWallet(tester, l10n.accountsSheetWallet(2));
      await openMenuOf(tester, second.name);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectAccount));
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectWalletConfirm));
      await tapVisible(tester, find.text(l10n.commonCancel));

      expect(await storedAccounts(), hasLength(3));
      expect(await SettingsService().getMnemonic(3), 'wallet three words');
    });

    testWidgets('a Keystone account: the hardware confirm, then it is removed', (tester) async {
      await seed([a1, keystone]);
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      await expandWallet(tester, l10n.accountsSheetKeystoneWallet(1));
      await openMenuOf(tester, keystone.name);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectAccount));

      expect(find.text(l10n.accountMenuDisconnectHardwareTitle), findsOneWidget);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnect));

      expect((await storedAccounts()).map((a) => a.accountId), [a1.accountId]);
    });

    testWidgets('a multisig: the multisig confirm, then it leaves the multisig list', (tester) async {
      await seed([a1, a2], multisigs: [multisig()]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, 'Msig');
      final l10n = l10nOf(tester);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectAccount));

      expect(find.text(l10n.accountMenuDisconnectMultisigTitle), findsOneWidget);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnect));

      expect(await SettingsService().getMultisigAccounts(), isEmpty);
      expect(await storedAccounts(), hasLength(2));
    });

    testWidgets('removing the active account makes a non-encrypted account active', (tester) async {
      await seed([a1, encrypted, a2], active: a1);
      await pumpAndOpen(tester);
      await openMenuOf(tester, a1.name);
      final l10n = l10nOf(tester);
      await tapVisible(tester, find.text(l10n.accountMenuDisconnectAccount));
      await tapVisible(tester, find.text(l10n.accountMenuDisconnect));

      expect((await SettingsService().getActiveAccount())?.account.accountId, a2.accountId);
    });
  });

  group('multisig details', () {
    testWidgets('list the creator first, label creator and you, and show the threshold', (tester) async {
      await seed([a1, a2], multisigs: [multisig(creator: outsider)]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, 'Msig');
      final l10n = l10nOf(tester);
      await tapVisible(tester, find.text(l10n.multisigAccountMenuDetails));

      expect(find.byType(MultisigDetailsScreen), findsOneWidget);
      final tiles = tester.widgetList<MultisigSignerListTile>(find.byType(MultisigSignerListTile)).toList();
      expect(tiles.map((t) => t.accountId), [outsider, a1.accountId, a2.accountId]);
      expect(tiles.map((t) => t.isCreator), [true, false, false]);
      expect(tiles.map((t) => t.isYou), [false, true, false]);
      expect(find.text(l10n.multisigThresholdOf(2, 3)), findsOneWidget);
    });

    testWidgets('keep the stored order when the creator is not a signer', (tester) async {
      await seed([a1, a2], multisigs: [multisig(creator: 'qznotasigner${'x' * 40}')]);
      await pumpAndOpen(tester);
      await openMenuOf(tester, 'Msig');
      await tapVisible(tester, find.text(l10nOf(tester).multisigAccountMenuDetails));

      final tiles = tester.widgetList<MultisigSignerListTile>(find.byType(MultisigSignerListTile)).toList();
      expect(tiles.map((t) => t.accountId), [a1.accountId, outsider, a2.accountId]);
      expect(tiles.map((t) => t.isCreator), [false, false, false]);
    });
  });

  group('rename', () {
    Future<void> openRename(WidgetTester tester, String name) async {
      await openMenuOf(tester, name);
      await tapVisible(tester, find.text(l10nOf(tester).accountMenuRename));
      expect(find.byType(EditAccountScreen), findsOneWidget);
    }

    testWidgets('an account is saved trimmed', (tester) async {
      await seed([a1, a2]);
      await pumpAndOpen(tester);
      await openRename(tester, a2.name);
      await enterName(tester, '  Savings  ');
      await tapVisible(tester, find.text(l10nOf(tester).editAccountDone));

      expect(find.byType(EditAccountScreen), findsNothing);
      expect((await storedAccounts()).firstWhere((a) => a.accountId == a2.accountId).name, 'Savings');
    });

    testWidgets('a blank name cannot be saved', (tester) async {
      await seed([a1, a2]);
      await pumpAndOpen(tester);
      await openRename(tester, a2.name);
      await enterName(tester, '   ');
      await tester.tap(find.text(l10nOf(tester).editAccountDone));
      await tester.pumpAndSettle();

      expect(find.byType(EditAccountScreen), findsOneWidget);
      expect((await storedAccounts()).firstWhere((a) => a.accountId == a2.accountId).name, a2.name);
    });

    testWidgets('an unchanged name closes the editor and keeps the name', (tester) async {
      await seed([a1, a2]);
      await pumpAndOpen(tester);
      await openRename(tester, a2.name);
      await enterName(tester, ' ${a2.name} ');
      await tapVisible(tester, find.text(l10nOf(tester).editAccountDone));

      expect(find.byType(EditAccountScreen), findsNothing);
      expect((await storedAccounts()).firstWhere((a) => a.accountId == a2.accountId).name, a2.name);
    });

    testWidgets('a multisig is saved trimmed', (tester) async {
      await seed([a1, a2], multisigs: [multisig()]);
      await pumpAndOpen(tester);
      await openRename(tester, 'Msig');
      await enterName(tester, '  Team  ');
      await tapVisible(tester, find.text(l10nOf(tester).editAccountDone));

      expect((await SettingsService().getMultisigAccounts()).single.name, 'Team');
    });

    testWidgets('a wallet is saved trimmed, and an empty name clears it', (tester) async {
      await seed([a1, a2]);
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      await tapVisible(tester, find.text(l10n.accountsSheetWallet(1)));
      await tapVisible(tester, find.text(l10n.accountMenuRename));
      expect(find.byType(WalletNameScreen), findsOneWidget);
      await enterName(tester, '  Daily  ');
      await tapVisible(tester, find.text(l10n.commonDone));

      expect(SettingsService().getWalletName(0), 'Daily');

      await tapVisible(tester, find.text('Daily'));
      await tapVisible(tester, find.text(l10n.accountMenuRename));
      await enterName(tester, '');
      await tapVisible(tester, find.text(l10n.commonDone));

      expect(SettingsService().getWalletName(0), isNull);
      expect(find.text(l10n.accountsSheetWallet(1)), findsOneWidget);
    });
  });
}
