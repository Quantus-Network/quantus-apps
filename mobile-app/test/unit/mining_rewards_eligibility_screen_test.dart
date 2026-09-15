import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_eligibility_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

ChainRewards _rewards(TestnetChain chain, {int blocks = 0, int rewardHundredths = 0}) => ChainRewards(
  chain: chain,
  blocksMined: blocks,
  rewardHundredths: rewardHundredths,
  matches: [
    if (blocks > 0) AirdropMatch(address: 'qz$blocks', kind: 'dilithium', scheme: 's', claimable: true, source: 'hd'),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));

  late Map<TestnetChain, Completer<ChainRewards>> pending;

  Future<void> pump(WidgetTester tester) async {
    pending = {for (final chain in TestnetChain.values) chain: Completer()};
    await tester.pumpApp(
      const MiningRewardsEligibilityScreen(walletIndex: 0),
      overrides: [
        isOnlineProvider.overrideWith((ref) => true),
        l10nProvider.overrideWithValue(l10n),
        settingsServiceProvider.overrideWithValue(FakeSettingsService()),
        chainEligibilityProvider.overrideWith((ref, check) => pending[check.chain]!.future),
      ],
    );
  }

  bool claimEnabled(WidgetTester tester) =>
      !tester.widget<QuantusButton>(find.byKey(const Key(E2EKeys.miningRewardsClaimButton))).isDisabled;

  testWidgets('each chain spins until it answers; the claim and total appear once all four have', (tester) async {
    await pump(tester);
    expect(find.text('Eligibility for Wallet 1'), findsOneWidget);
    expect(find.byType(Loader), findsNWidgets(4));
    expect(claimEnabled(tester), isFalse);

    pending[TestnetChain.resonance]!.complete(_rewards(TestnetChain.resonance, blocks: 120, rewardHundredths: 6539));
    pending[TestnetChain.schrodinger]!.complete(_rewards(TestnetChain.schrodinger, blocks: 1, rewardHundredths: 10));
    await tester.pump();
    expect(find.byType(Loader), findsNWidgets(2));
    expect(find.text('120 blocks mined'), findsOneWidget);
    expect(find.text('65.39 QTC'), findsOneWidget);
    expect(find.text('1 block mined'), findsOneWidget);
    expect(find.text('0.1 QTC'), findsOneWidget);
    expect(find.text(l10n.miningRewardsTotal), findsNothing);
    expect(claimEnabled(tester), isFalse);

    pending[TestnetChain.dirac]!.complete(_rewards(TestnetChain.dirac));
    pending[TestnetChain.planck]!.complete(_rewards(TestnetChain.planck));
    await tester.pump();
    expect(find.byType(Loader), findsNothing);
    expect(find.text('0 blocks mined'), findsNWidgets(2));
    expect(find.text(l10n.miningRewardsTotal), findsOneWidget);
    expect(find.text('65.49 QTC'), findsOneWidget);
    expect(find.text(l10n.miningRewardsNone), findsNothing);
    expect(claimEnabled(tester), isTrue);
  });

  testWidgets('a wallet that mined nowhere is told so and cannot claim', (tester) async {
    await pump(tester);
    for (final chain in TestnetChain.values) {
      pending[chain]!.complete(_rewards(chain));
    }
    await tester.pump();
    expect(find.text(l10n.miningRewardsNone), findsOneWidget);
    expect(claimEnabled(tester), isFalse);
  });

  testWidgets('a failed chain offers a retry and keeps the claim closed', (tester) async {
    await pump(tester);
    for (final chain in TestnetChain.values.skip(1)) {
      pending[chain]!.complete(_rewards(chain, blocks: 500, rewardHundredths: 100));
    }
    pending[TestnetChain.resonance]!.completeError(Exception('table missing'));
    await tester.pump();
    expect(find.text(l10n.miningRewardsCheckFailed), findsOneWidget);
    expect(find.text(l10n.miningRewardsTotal), findsNothing);
    expect(claimEnabled(tester), isFalse);
  });
}
