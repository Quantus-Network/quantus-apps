import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));
  final accounts = [
    makeAccount(0),
    const Account(walletIndex: 1, index: 0, name: 'Account 1', accountId: 'qzsecondwalletxxxxxxxxxxxxxxxxxxxxxxxx'),
    makeAccount(1, accountType: AccountType.keystone),
  ];
  final claimed = AirdropClaimRecord(
    claimedAt: DateTime(2026, 9, 16),
    rewardHundredths: 12180,
    claimAccount: 'qzpaidhere',
    accountName: 'Account 0',
  );

  Future<void> pump(WidgetTester tester) => tester.pumpApp(
    const MiningRewardsScreen(),
    overrides: [
      isOnlineProvider.overrideWith((ref) => true),
      l10nProvider.overrideWithValue(l10n),
      settingsServiceProvider.overrideWithValue(FakeSettingsService()),
      accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: accounts)),
      airdropClaimRecordProvider.overrideWith((ref, walletIndex) => walletIndex == 0 ? claimed : null),
      chainEligibilityProvider.overrideWith((ref, check) => Completer<ChainRewards>().future),
    ],
  );

  testWidgets('lists each software wallet with what it already claimed', (tester) async {
    await pump(tester);
    expect(find.text('WALLETS'), findsOneWidget);
    expect(find.text('Wallet 1'), findsOneWidget);
    expect(find.text('121.80 QTC'), findsOneWidget);
    expect(find.text(l10n.miningRewardsClaimedTag), findsOneWidget);
    expect(find.text('Wallet 2'), findsOneWidget);
    expect(find.text(l10n.miningRewardsNotClaimed), findsOneWidget);
    expect(find.byKey(Key(E2EKeys.miningRewardsWalletRow(0))), findsOneWidget);
    expect(find.byKey(Key(E2EKeys.miningRewardsWalletRow(1))), findsOneWidget);
  });

  testWidgets('tapping a wallet opens its rewards directly', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Wallet 2'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key(E2EKeys.miningRewardsWalletScreen)), findsOneWidget);
    expect(find.text('Wallet 2'), findsOneWidget);
  });
}
