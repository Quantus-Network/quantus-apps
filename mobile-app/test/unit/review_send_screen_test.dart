import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/review_send_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_fee_notifier.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_screen_logic.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions.dart';
import '../fakes.dart';

/// Review re-derives its figures from the live fee. A max send waits for the
/// settled `transfer_all` fee; an ordinary send is only blocked when the
/// settled fee no longer fits the balance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sender = makeAccount(1);
  final recipient = makeAccount(2);
  final spendable = BigInt.from(5) * NumberFormattingService.scaleFactorBigInt;
  final lowFee = BigInt.from(10).pow(10);
  final highFee = BigInt.two * lowFee;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  Future<ProviderContainer> pumpReview(
    WidgetTester tester, {
    required BigInt amount,
    required SendFee fee,
    bool sendAll = false,
    BigInt? balance,
  }) async {
    await tester.pumpApp(
      ReviewSendScreen(
        strategy: RegularSendStrategy(account: sender),
        recipientAddress: recipient.accountId,
        amount: amount,
        fee: fee,
        recipientChecksum: 'Stand-Envelope-Topic-Term-Help',
        sendAll: sendAll,
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(sender))),
        effectiveMaxBalanceProviderFamily.overrideWith((ref, accountId) => AsyncValue.data(balance ?? spendable)),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(ReviewSendScreen)));
  }

  /// A quote lands on its fetch future; a second pump draws the frame that schedules.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  bool confirmDisabled(WidgetTester tester) =>
      tester.widget<QuantusButton>(find.byKey(const Key(E2EKeys.sendConfirmButton))).isDisabled;

  String amt(ProviderContainer container, BigInt v) {
    final fmt = container.read(numberFormattingServiceProvider);
    return container
        .read(l10nProvider)
        .commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);
  }

  testWidgets('a max send waits for the transfer_all fee, then shows the exact split', (tester) async {
    final container = await pumpReview(
      tester,
      amount: spendable - lowFee,
      fee: RegularFee(networkFee: lowFee),
      sendAll: true,
    );
    expect(confirmDisabled(tester), isTrue);
    // The hero repeats the amount, so it shows twice.
    expect(find.text('~${amt(container, spendable - lowFee)}'), findsNWidgets(2));
    expect(find.text('~${amt(container, lowFee)}'), findsOneWidget);
    expect(find.text(amt(container, spendable)), findsOneWidget);

    final query = Completer<SendFee>();
    container.read(sendFeeProvider.notifier).request(() => query.future, immediate: true);
    await settle(tester);
    expect(confirmDisabled(tester), isTrue);

    query.complete(RegularFee(networkFee: highFee, sendAll: true));
    await settle(tester);

    expect(confirmDisabled(tester), isFalse);
    expect(find.textContaining('~'), findsNothing);
    expect(find.text(amt(container, spendable - highFee)), findsNWidgets(2));
    expect(find.text(amt(container, highFee)), findsOneWidget);
    expect(find.text(amt(container, spendable)), findsOneWidget);
  });

  testWidgets('a max send whose fee query fails offers retry and stays blocked until it lands', (tester) async {
    final container = await pumpReview(
      tester,
      amount: spendable - lowFee,
      fee: RegularFee(networkFee: lowFee),
      sendAll: true,
    );
    final l10n = container.read(l10nProvider);
    var fail = true;
    container.read(sendFeeProvider.notifier).request(() async {
      if (fail) throw Exception('rpc down');
      return RegularFee(networkFee: highFee, sendAll: true);
    }, immediate: true);
    await settle(tester);

    expect(confirmDisabled(tester), isTrue);
    expect(find.text(l10n.multisigProposeFeeFetchFailed), findsOneWidget);

    fail = false;
    await tester.tap(find.text(l10n.homeActivityRetry));
    await settle(tester);

    expect(confirmDisabled(tester), isFalse);
    expect(find.text(l10n.multisigProposeFeeFetchFailed), findsNothing);
    expect(find.text(amt(container, spendable - highFee)), findsNWidgets(2));
  });

  testWidgets('a max send whose settled fee leaves less than the minimum stays blocked', (tester) async {
    final minimum = SendScreenLogic.minimumSendAmount;
    final estimate = minimum ~/ BigInt.from(4);
    final container = await pumpReview(
      tester,
      amount: minimum,
      fee: RegularFee(networkFee: estimate),
      sendAll: true,
      balance: minimum + estimate,
    );
    final notifier = container.read(sendFeeProvider.notifier);
    expect(confirmDisabled(tester), isTrue);

    notifier.request(() async => RegularFee(networkFee: estimate * BigInt.two, sendAll: true), immediate: true);
    await settle(tester);
    expect(confirmDisabled(tester), isTrue);
    final l10n = container.read(l10nProvider);
    final fmt = container.read(numberFormattingServiceProvider);
    expect(find.text(l10n.sendLogicBelowMinimum(fmt.formatAmount(minimum), AppConstants.tokenSymbol)), findsOneWidget);

    notifier.request(() async => RegularFee(networkFee: estimate, sendAll: true), immediate: true);
    await settle(tester);
    expect(confirmDisabled(tester), isFalse);
  });

  testWidgets('an ordinary send with fee headroom is not blocked by an unsettled fee', (tester) async {
    final container = await pumpReview(
      tester,
      amount: lowFee * BigInt.from(100),
      fee: RegularFee(networkFee: lowFee),
    );

    expect(confirmDisabled(tester), isFalse);
    expect(find.text('~${amt(container, lowFee)}'), findsOneWidget);
  });

  testWidgets('an ordinary send near the balance waits for its exact fee, then blocks or allows on it', (tester) async {
    final amount = spendable - lowFee;
    final container = await pumpReview(
      tester,
      amount: amount,
      fee: RegularFee(networkFee: lowFee, amount: amount),
    );
    final notifier = container.read(sendFeeProvider.notifier);
    expect(confirmDisabled(tester), isTrue);
    expect(find.text('~${amt(container, lowFee)}'), findsOneWidget);

    notifier.request(() async => RegularFee(networkFee: highFee, amount: amount), immediate: true);
    await settle(tester);
    expect(confirmDisabled(tester), isTrue);
    expect(find.text(container.read(l10nProvider).sendLogicInsufficientBalance), findsOneWidget);

    notifier.request(() async => RegularFee(networkFee: lowFee, amount: amount), immediate: true);
    await settle(tester);
    expect(confirmDisabled(tester), isFalse);
    expect(find.textContaining('~'), findsNothing);
  });

  testWidgets('a quote for another amount never satisfies a near-balance send', (tester) async {
    final amount = spendable - lowFee;
    final container = await pumpReview(
      tester,
      amount: amount,
      fee: RegularFee(networkFee: lowFee, amount: amount),
    );
    container
        .read(sendFeeProvider.notifier)
        .request(() async => RegularFee(networkFee: lowFee, amount: SendStrategy.feeProbeAmount), immediate: true);
    await settle(tester);

    expect(container.read(sendFeeProvider).settled, isTrue);
    expect(confirmDisabled(tester), isTrue);
  });
}
