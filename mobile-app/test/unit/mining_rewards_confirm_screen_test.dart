import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_confirm_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

class _Service extends Fake implements MiningRewardsService {
  final int failures;
  int calls = 0;
  List<ChainRewards>? rewards;
  ClaimDestination? destination;

  _Service({this.failures = 0});

  @override
  Future<void> submitClaims({
    required int walletIndex,
    required List<ChainRewards> rewards,
    required ClaimDestination destination,
  }) async {
    calls++;
    this.rewards = rewards;
    this.destination = destination;
    if (calls <= failures) throw Exception('server unreachable');
  }
}

class _Checksums extends Fake implements HumanReadableChecksumService {
  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) async => 'CHECK PHRASE';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));
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
  final destination = ClaimDestination(address: 'qzpaidhere${'x' * 40}', accountName: 'Account 1');

  Future<void> pump(WidgetTester tester, _Service service) => tester.pumpApp(
    MiningRewardsConfirmScreen(walletIndex: 0, rewards: rewards, destination: destination),
    overrides: [
      isOnlineProvider.overrideWith((ref) => true),
      l10nProvider.overrideWithValue(l10n),
      settingsServiceProvider.overrideWithValue(FakeSettingsService()),
      humanReadableChecksumServiceProvider.overrideWithValue(_Checksums()),
      miningRewardsServiceProvider.overrideWithValue(service),
    ],
  );

  testWidgets('shows amount, destination and payout day, then submits and confirms', (tester) async {
    final service = _Service();
    await pump(tester, service);
    await tester.pump();
    expect(find.text('121.80 QTC'), findsNWidgets(2));
    expect(find.text('CHECK PHRASE'), findsOneWidget);
    expect(find.text(AddressFormattingService.formatAddress(destination.address)), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);

    await tester.tap(find.byKey(const Key(E2EKeys.miningRewardsSubmitButton)));
    await tester.pumpAndSettle();
    expect(service.rewards, rewards);
    expect(service.destination, destination);
    expect(find.text('Paying to Account 1.'), findsOneWidget);
    expect(find.text(l10n.miningRewardsSubmittedNote), findsOneWidget);
  });

  testWidgets('a failed submission shows the failed page and Try Again submits again', (tester) async {
    final service = _Service(failures: 1);
    await pump(tester, service);
    await tester.tap(find.byKey(const Key(E2EKeys.miningRewardsSubmitButton)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.miningRewardsSubmitFailedTitle), findsOneWidget);
    expect(find.text(l10n.miningRewardsSubmitFailedBody2), findsOneWidget);

    await tester.tap(find.byKey(const Key(E2EKeys.miningRewardsTryAgainButton)));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('Paying to Account 1.'), findsOneWidget);
  });
}
