import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_wallet_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

String _address(TestnetChain chain, int i) => '${'qz${chain.name}$i'.padRight(48, 'x')}$i';

/// One [ChainRewards] from (blocks, reward hundredths) per owned address.
ChainRewards _rewards(TestnetChain chain, List<(int, int)> rows) => ChainRewards(
  chain: chain,
  rows: [
    for (final (i, (blocks, hundredths)) in rows.indexed)
      AddressReward(
        match: AirdropMatch(address: _address(chain, i), kind: 'dilithium', scheme: 's', claimable: true, source: 'hd'),
        reward: MinerReward(blocks: blocks, rewardHundredths: hundredths),
      ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('en'));
  final l10n = lookupAppLocalizations(const Locale('en'));
  final accounts = [makeAccount(0), makeAccount(1)];

  late Map<TestnetChain, Completer<ChainRewards>> pending;

  Future<void> pump(WidgetTester tester, {AirdropClaimRecord? record}) async {
    pending = {for (final chain in TestnetChain.values) chain: Completer()};
    await tester.pumpApp(
      const MiningRewardsWalletScreen(walletIndex: 0),
      overrides: [
        isOnlineProvider.overrideWith((ref) => true),
        l10nProvider.overrideWithValue(l10n),
        settingsServiceProvider.overrideWithValue(FakeSettingsService()),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: accounts)),
        chainEligibilityProvider.overrideWith((ref, check) => pending[check.chain]!.future),
        airdropClaimRecordProvider.overrideWith((ref, walletIndex) => record),
      ],
    );
  }

  bool claimEnabled(WidgetTester tester) =>
      !tester.widget<QuantusButton>(find.byKey(const Key(E2EKeys.miningRewardsClaimButton))).isDisabled;

  testWidgets('counts chains as they answer, then shows the totals and opens a chain sheet', (tester) async {
    await pump(tester);
    expect(find.text('CHECKING 2 ADDRESSES'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('of 4'), findsOneWidget);
    expect(find.byType(Loader), findsNWidgets(4));
    expect(claimEnabled(tester), isFalse);

    pending[TestnetChain.resonance]!.complete(_rewards(TestnetChain.resonance, [(500, 1833), (11, 10)]));
    pending[TestnetChain.schrodinger]!.complete(_rewards(TestnetChain.schrodinger, [(5200, 7304), (79, 10)]));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('18.43 QTC'), findsOneWidget);
    expect(find.text('73.14 QTC'), findsOneWidget);
    expect(find.byType(Loader), findsNWidgets(2));
    expect(claimEnabled(tester), isFalse);

    pending[TestnetChain.dirac]!.complete(_rewards(TestnetChain.dirac, []));
    pending[TestnetChain.planck]!.complete(_rewards(TestnetChain.planck, []));
    await tester.pump();
    expect(find.byType(Loader), findsNothing);
    expect(find.text('TOTAL REWARDS'), findsOneWidget);
    expect(find.text('91.57'), findsOneWidget);
    expect(find.text('18.43'), findsOneWidget);
    expect(find.text('511 blocks'), findsOneWidget);
    expect(find.text('5,279 blocks'), findsOneWidget);
    expect(find.text('Not mined'), findsNWidgets(2));
    expect(claimEnabled(tester), isTrue);

    await tester.tap(find.byKey(Key(E2EKeys.miningRewardsChainRow('resonance'))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final sheet = find.byKey(const Key(E2EKeys.miningRewardsChainSheet));
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Resonance')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('511')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('18.43 QTC')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('18.33')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('0.10')), findsOneWidget);
    for (final i in [0, 1]) {
      final short = AddressFormattingService.formatAddress(_address(TestnetChain.resonance, i));
      expect(find.descendant(of: sheet, matching: find.text(short)), findsOneWidget);
    }
  });

  testWidgets('a wallet that mined nowhere gets the no-mining page', (tester) async {
    await pump(tester);
    for (final chain in TestnetChain.values) {
      pending[chain]!.complete(_rewards(chain, []));
    }
    await tester.pump();
    expect(find.text(l10n.miningRewardsNoMiningTitle), findsOneWidget);
    expect(find.byKey(const Key(E2EKeys.miningRewardsTryAnotherWalletButton)), findsOneWidget);
    expect(find.byKey(const Key(E2EKeys.miningRewardsClaimButton)), findsNothing);
  });

  testWidgets('a failed chain keeps the counter short and can be retried from its row', (tester) async {
    await pump(tester);
    for (final chain in TestnetChain.values.skip(1)) {
      pending[chain]!.complete(_rewards(chain, [(1, 10)]));
    }
    pending[TestnetChain.resonance]!.completeError(Exception('table missing'));
    await tester.pump();
    expect(find.text(l10n.miningRewardsCheckFailed), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(claimEnabled(tester), isFalse);

    pending[TestnetChain.resonance] = Completer();
    await tester.tap(find.text(l10n.miningRewardsCheckFailed));
    await tester.pump();
    expect(find.byType(Loader), findsOneWidget);

    pending[TestnetChain.resonance]!.complete(_rewards(TestnetChain.resonance, [(2, 10)]));
    await tester.pump();
    expect(find.text('TOTAL REWARDS'), findsOneWidget);
    expect(find.text('0.40'), findsOneWidget);
    expect(claimEnabled(tester), isTrue);
  });

  testWidgets('a wallet that already claimed sees its claim instead of a new check', (tester) async {
    final record = AirdropClaimRecord(
      claimedAt: DateTime(2026, 9, 16),
      rewardHundredths: 12180,
      claimAccount: 'qzpaidhere${'x' * 40}',
      accountName: 'Account 1',
    );
    await pump(tester, record: record);
    expect(find.text('CLAIMED 16 SEP'), findsOneWidget);
    expect(find.text('121.80'), findsOneWidget);
    expect(find.text(l10n.miningRewardsPayingTo), findsOneWidget);
    expect(find.text(AddressFormattingService.formatAddress(record.claimAccount)), findsOneWidget);
    expect(find.text(l10n.miningRewardsNextPayout), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.byKey(const Key(E2EKeys.miningRewardsCheckAnotherWalletButton)), findsOneWidget);
    expect(find.byType(Loader), findsNothing);
  });
}
