import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/wallet_name_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  final accounts = [makeAccount(1), makeAccount(2)];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

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
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(accounts.first))),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: accounts)),
        balanceProviderFamily.overrideWith((ref, accountId) async => BigInt.from(10).pow(15)),
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

  Future<void> openRowMenu(WidgetTester tester) async {
    await tester.tap(find.byType(KebabButton).first);
    await tester.pumpAndSettle();
  }

  group('accounts screen', () {
    testWidgets('a glass caret in the left slot closes the screen', (tester) async {
      await pumpAndOpen(tester);
      final button = tester.widget<AppBackButton>(find.byType(AppBackButton));
      expect(button.icon, QuantusIcons.caretDown);
      expect(button.size, 44);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AccountsScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('the kebab drops the account menu over the list', (tester) async {
      await pumpAndOpen(tester);
      await openRowMenu(tester);
      final l10n = l10nOf(tester);
      expect(find.byType(AccountMenuScreen), findsNothing);
      expect(find.byType(AccountsScreen), findsOneWidget);
      expect(find.text(l10n.accountMenuShowAddress), findsOneWidget);
      expect(find.text(l10n.accountMenuRename), findsOneWidget);
      expect(find.text(l10n.accountMenuShowRecoveryPhrase), findsOneWidget);
      expect(find.text(l10n.accountMenuDisconnectAccount), findsOneWidget);
    });

    testWidgets('show address opens the address details', (tester) async {
      await pumpAndOpen(tester);
      await openRowMenu(tester);
      await tester.tap(find.text(l10nOf(tester).accountMenuShowAddress));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AccountDetailsScreen), findsOneWidget);
      expect(
        tester.widget<AccountDetailsScreen>(find.byType(AccountDetailsScreen)).accountId,
        accounts.first.accountId,
      );
    });

    testWidgets('disconnect asks for confirmation first', (tester) async {
      await pumpAndOpen(tester);
      await openRowMenu(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.accountMenuDisconnectAccount));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountMenuDisconnectAccountTitle), findsOneWidget);
      expect(find.byType(AccountsScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('the wallet name drops a menu that renames the wallet', (tester) async {
      await pumpAndOpen(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.accountsSheetWallet(1)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountMenuRename), findsOneWidget);
      await tester.tap(find.text(l10n.accountMenuRename));
      await tester.pumpAndSettle();
      expect(find.byType(WalletNameScreen), findsOneWidget);
    });
  });
}
