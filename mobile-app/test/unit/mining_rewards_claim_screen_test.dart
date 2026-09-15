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
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_claim_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

class _Service extends Fake implements MiningRewardsService {
  int? walletIndex;
  List<AirdropMatch>? matches;
  String? claimAccount;

  @override
  Future<void> submitClaims({
    required int walletIndex,
    required List<AirdropMatch> matches,
    required String claimAccount,
  }) async {
    this.walletIndex = walletIndex;
    this.matches = matches;
    this.claimAccount = claimAccount;
  }
}

class _Checksums extends Fake implements HumanReadableChecksumService {
  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) async => 'CHECK PHRASE';
}

AirdropMatch _match(String address) =>
    AirdropMatch(address: address, kind: 'dilithium', scheme: 's', claimable: true, source: 'hd');

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
  final eligible = ChainRewards(
    chain: TestnetChain.dirac,
    blocksMined: 300,
    rewardHundredths: 6539,
    matches: [_match('qzdirac')],
  );
  const ineligible = ChainRewards(chain: TestnetChain.planck, blocksMined: 0, rewardHundredths: 0, matches: []);

  late _Service service;

  Future<void> pump(WidgetTester tester) async {
    service = _Service();
    await tester.pumpApp(
      MiningRewardsClaimScreen(walletIndex: 0, eligibilities: [eligible, ineligible]),
      overrides: [
        isOnlineProvider.overrideWith((ref) => true),
        l10nProvider.overrideWithValue(l10n),
        settingsServiceProvider.overrideWithValue(FakeSettingsService()),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: accounts)),
        substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
        humanReadableChecksumServiceProvider.overrideWithValue(_Checksums()),
        miningRewardsServiceProvider.overrideWithValue(service),
      ],
    );
  }

  bool submitEnabled(WidgetTester tester) =>
      !tester.widget<QuantusButton>(find.byKey(const Key(E2EKeys.miningRewardsSubmitButton))).isDisabled;

  testWidgets('lists transparent and encrypted accounts; picking one fills the beneficiary', (tester) async {
    await pump(tester);
    expect(find.text('Account 0'), findsOneWidget);
    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text(l10n.miningRewardsPayoutInfo), findsOneWidget);
    expect(submitEnabled(tester), isFalse);

    await tester.dragUntilVisible(find.text('Encrypted'), find.byType(ListView), const Offset(0, -80));
    await tester.tap(find.text('Encrypted'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, encrypted.accountId);
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('submits only the eligible chains to the typed address, then confirms', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'qzsomeone');
    await tester.pump();
    expect(submitEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key(E2EKeys.miningRewardsSubmitButton)));
    await tester.pumpAndSettle();

    expect(service.walletIndex, 0);
    expect(service.claimAccount, 'qzsomeone');
    expect(service.matches, eligible.matches);
    expect(find.text(l10n.miningRewardsSubmittedBody), findsOneWidget);
  });
}
