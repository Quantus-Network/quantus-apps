import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  Future<ProviderContainer> pumpHome(WidgetTester tester, {required FakeSettingsService settings}) async {
    await tester.pumpApp(
      const HomeScreen(),
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        activeAccountTransactionsProvider.overrideWith(
          (ref, filter) => AsyncValue.data(CombinedTransactionsList.empty),
        ),
        balanceProvider.overrideWithValue(AsyncValue.data(BigInt.from(10).pow(15))),
        balanceProviderFamily.overrideWith((ref, accountId) async => BigInt.from(10).pow(15)),
        balanceDisplayProvider.overrideWithValue(
          const AsyncValue.data(
            CurrencyDisplayState(primaryAmount: '10', secondaryAmount: '10', selectedFiat: FiatCurrency.usd),
          ),
        ),
        backupReminderWalletIndexProvider.overrideWithValue(null),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
        substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
      ],
    );
    // Let the active account and multisig list finish their async load.
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  testWidgets('home actions show receive and send, and swap per the flag', (tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)));
    await pumpHome(tester, settings: settings);

    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Swap'), AppConstants.showSwapButton ? findsOneWidget : findsNothing);
  });

  testWidgets('payment intent opens the send flow bound to the active account', (tester) async {
    final active = makeAccount(1);
    final settings = FakeSettingsService(activeAccount: RegularAccount(active));
    final container = await pumpHome(tester, settings: settings);

    // A cached QR from an earlier flow must not survive into the new session.
    container
        .read(keystoneSignCacheProvider.notifier)
        .store(
          key: KeystoneSignCacheKey.fromSendParams(
            accountId: active.accountId,
            recipientAddress: makeAccount(9).accountId,
            amount: BigInt.one,
          ),
          unsignedData: makeUnsignedTransactionData(),
          urParts: const ['ur:part'],
        );

    container.read(paymentIntentProvider.notifier).state = PaymentIntent(to: makeAccount(9).accountId, amount: '1.5');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(paymentIntentProvider), isNull);
    expect(find.byType(InputAmountScreen), findsOneWidget);
    final screen = tester.widget<InputAmountScreen>(find.byType(InputAmountScreen));
    expect((screen.strategy as RegularSendStrategy).account.accountId, active.accountId);
    expect(container.read(sendFlowActiveProvider), isTrue);
    expect(container.read(keystoneSignCacheProvider), isNull);
  });

  testWidgets('intent arriving during a send flow is dropped', (tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)));
    final container = await pumpHome(tester, settings: settings);

    container.read(paymentIntentProvider.notifier).state = PaymentIntent(to: makeAccount(9).accountId, amount: '1.5');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InputAmountScreen), findsOneWidget);
    expect(container.read(sendFlowActiveProvider), isTrue);

    container.read(proposalIntentProvider.notifier).state = const ProposalIntent(
      multisigAddress: 'unknown-msig',
      proposalId: 7,
    );
    await tester.pump();
    expect(container.read(proposalIntentProvider), isNull);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(InputAmountScreen), findsNothing);
    expect(container.read(sendFlowActiveProvider), isFalse);
  });
}
