import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';
import 'package:resonance_network_wallet/v2/components/account_list_row.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_pay_to_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

class _Checksums extends Fake implements HumanReadableChecksumService {
  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) async => 'CHECK PHRASE';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));
  final encrypted = Account(
    walletIndex: 0,
    index: AppConstants.encryptedAccountIndex,
    name: 'Encrypted',
    accountId: 'qzencrypted${'x' * 40}',
    accountType: AccountType.encrypted,
  );
  final accounts = [makeAccount(0), makeAccount(1), encrypted];
  const rewards = [
    ChainRewards(
      chain: TestnetChain.dirac,
      rows: [
        AddressReward(
          match: AirdropMatch(address: 'qzdirac', kind: 'dilithium', scheme: 's', claimable: true, source: 'hd'),
          reward: MinerReward(blocks: 300, rewardHundredths: 12180),
        ),
      ],
    ),
  ];

  Future<void> pump(WidgetTester tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(accounts[1]));
    await tester.pumpApp(
      const MiningRewardsPayToScreen(walletIndex: 0, rewards: rewards),
      overrides: [
        isOnlineProvider.overrideWith((ref) => true),
        l10nProvider.overrideWithValue(l10n),
        settingsServiceProvider.overrideWithValue(settings),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: accounts)),
        activeAccountProvider.overrideWith((ref) => ActiveAccountNotifier(settings)),
        humanReadableChecksumServiceProvider.overrideWithValue(_Checksums()),
      ],
    );
    await tester.pump();
  }

  Finder checkIn(String accountName) =>
      find.descendant(of: find.widgetWithText(AccountListRow, accountName), matching: find.byIcon(Icons.check));

  testWidgets('lists every account by wallet, preselects the active one, and carries the pick to confirm', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('121.80'), findsOneWidget);
    expect(find.text(l10n.miningRewardsPayToIntro), findsOneWidget);
    expect(find.text('WALLET 1'), findsOneWidget);
    expect(find.text('Account 0'), findsOneWidget);
    expect(find.text('Encrypted'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(checkIn('Account 1'), findsOneWidget);

    await tester.tap(find.text('Account 0'));
    await tester.pump();
    expect(checkIn('Account 0'), findsOneWidget);
    expect(checkIn('Account 1'), findsNothing);

    await tester.tap(find.byKey(const Key(E2EKeys.miningRewardsContinueButton)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.miningRewardsConfirmTitle), findsOneWidget);
    expect(find.text(AddressFormattingService.formatAddress(accounts[0].accountId)), findsOneWidget);
  });

  testWidgets('use another address opens the typed-address screen', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key(E2EKeys.miningRewardsUseAnotherAddressButton)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.miningRewardsAnotherAddressTitle), findsOneWidget);
  });
}
