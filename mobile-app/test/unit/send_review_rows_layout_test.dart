import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/multisig_expiry_value.dart';
import 'package:resonance_network_wallet/v2/screens/send/multisig_propose_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/review_send_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_fee_notifier.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/exchange_rate_service.dart';

import '../extensions.dart';
import '../fakes.dart';

class _FakeMultisigService extends Fake implements MultisigService {
  @override
  Future<int> currentBlockNumber() async => 100;

  @override
  DateTime blockToTime(int targetBlock, int currentBlock) => DateTime.utc(2026);
}

/// What the review screen's summary holds, top to bottom: each gap by its
/// height, each row by its label, its value, how wide the value may grow and
/// the address whose checkphrase it shows.
List<String> _summary(WidgetTester tester) {
  final column = tester.widget<Column>(
    find.ancestor(of: find.byType(DetailSummaryRow).first, matching: find.byType(Column)).first,
  );
  return [
    for (final child in column.children)
      switch (child) {
        SizedBox(:final height) => 'gap $height',
        DetailSummaryRow(:final valueWidget) =>
          'row ${child.label} | '
              '${valueWidget is MultisigExpiryValue ? '${valueWidget.parts.blockLabel} / ${valueWidget.parts.estimatedDateTime}' : child.value} | '
              'flex ${child.valueFlex} | checkphrase ${child.checkphraseAddress} | padding ${child.padding}',
        _ => 'other ${child.runtimeType}',
      },
  ];
}

/// The review screen's summary rows, as drawn for each kind of send. Pins the
/// rows and the gaps between them, which the shared send logic describes and
/// this app draws.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help';
  final sender = makeAccount(1);
  final recipient = makeAccount(2);
  final oneToken = NumberFormattingService.scaleFactorBigInt;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  String amt(ProviderContainer container, BigInt v) {
    final fmt = container.read(numberFormattingServiceProvider);
    return container
        .read(l10nProvider)
        .commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);
  }

  testWidgets('a transfer is summed up in four rows, seven apart', (tester) async {
    final fee = BigInt.from(10).pow(10);
    await tester.pumpApp(
      ReviewSendScreen(
        strategy: RegularSendStrategy(account: sender),
        recipientAddress: recipient.accountId,
        amount: oneToken,
        fee: RegularFee(networkFee: fee, amount: oneToken),
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(sender))),
        effectiveBalanceProviderFamily.overrideWith((ref, accountId) => AsyncValue.data(BigInt.from(5) * oneToken)),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(ReviewSendScreen)));
    // The exact fee for this send, so no figure is marked as an estimate.
    container
        .read(sendFeeProvider.notifier)
        .request(() async => RegularFee(networkFee: fee, amount: oneToken), immediate: true);
    await tester.pump();
    await tester.pump();

    final l10n = container.read(l10nProvider);
    const zero = EdgeInsets.zero;
    expect(_summary(tester), [
      'gap 7.0',
      'row ${l10n.sendReviewTo} | ${recipient.accountId} | flex 3 | checkphrase null | padding $zero',
      'gap 7.0',
      'row ${l10n.sendReviewAmount} | ${amt(container, oneToken)} | flex 3 | checkphrase null | padding $zero',
      'gap 7.0',
      'row ${l10n.sendReviewNetworkFee} | ${amt(container, fee)} | flex 3 | checkphrase null | padding $zero',
      'gap 7.0',
      'row ${l10n.sendReviewYouPay} | ${amt(container, oneToken + fee)} | flex 3 | checkphrase null | padding $zero',
      'gap 7.0',
    ]);
  });

  testWidgets('a multisig proposal is summed up in eight rows, four apart', (tester) async {
    final msig = makeMultisigAccount();
    final breakdown = ProposeFeeBreakdown(
      networkFee: BigInt.from(10).pow(10),
      deposit: BigInt.two * oneToken,
      creationFee: BigInt.from(3) * oneToken,
      expiryBlock: 1000,
    );
    await tester.pumpApp(
      ReviewSendScreen(
        strategy: MultisigProposeStrategy(msig: msig),
        recipientAddress: recipient.accountId,
        amount: oneToken,
        fee: ProposeFee(breakdown),
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(sender))),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: [sender])),
        balanceProviderFamily.overrideWith((ref, accountId) => BigInt.from(5) * oneToken),
        effectiveBalanceProviderFamily.overrideWith((ref, accountId) => AsyncValue.data(BigInt.from(50) * oneToken)),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        multisigServiceProvider.overrideWithValue(_FakeMultisigService()),
        multisigProposeFeeProvider.overrideWith((ref, key) async => ProposeFee(breakdown)),
      ],
    );
    // The current block, which the expiry's estimated time is worked out from.
    await tester.pump();
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(ReviewSendScreen)));

    final l10n = container.read(l10nProvider);
    final member = msig.myMemberAccountId;
    final expires =
        '${l10n.multisigExpiresBlockOnly(1000)} / ~${DatetimeFormattingService.formatTxDateTime(DateTime.utc(2026))}';
    const zero = EdgeInsets.zero;
    expect(_summary(tester), [
      'gap 4.0',
      'row ${l10n.multisigProposeProposerLabel} | $member | flex 4 | checkphrase $member | padding $zero',
      'gap 4.0',
      'row ${l10n.sendReviewAmount} | ${amt(container, oneToken)} | flex 3 | checkphrase null | padding $zero',
      'gap 4.0',
      'row ${l10n.multisigProposeThresholdLabel} | 1/1 | flex 3 | checkphrase null | padding $zero',
      'gap 4.0',
      'row ${l10n.multisigProposeExpiresLabel} | $expires | flex 4 | checkphrase null | padding $zero',
      'gap 4.0',
      'row ${l10n.sendReviewNetworkFee} | ${amt(container, breakdown.networkFee)} | flex 3 | checkphrase null | padding $zero',
      'gap 4.0',
      'row ${l10n.multisigProposalDepositLabel} | ${amt(container, breakdown.deposit)} | flex 3 | checkphrase null | padding $zero',
      'gap 4.0',
      'row ${l10n.multisigProposeFeeRowLabel} | ${amt(container, breakdown.creationFee)} | flex 3 | checkphrase null | padding $zero',
      'gap 4.0',
      'row ${l10n.multisigProposeMemberTotalLabel} | ${amt(container, breakdown.memberCost)} | flex 3 | checkphrase null | padding $zero',
      'gap 4.0',
    ]);
  });
}
