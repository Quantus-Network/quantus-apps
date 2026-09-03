import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/shared/constants/feature_flags.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
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
  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required FakeSettingsService settings,
    required TestLocalAuthController auth,
  }) async {
    await tester.pumpApp(
      const HomeScreen(),
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        localAuthProvider.overrideWith((ref) => auth),
        activeAccountTransactionsProvider.overrideWith(
          (ref, filter) => AsyncValue.data(CombinedTransactionsList.empty),
        ),
        balanceProvider.overrideWithValue(AsyncValue.data(BigInt.from(10).pow(15))),
        balanceProviderFamily.overrideWith((ref, accountId) async => BigInt.from(10).pow(15)),
        balanceDisplayProvider.overrideWithValue(
          const AsyncValue.data(
            CurrencyDisplayState(
              primaryAmount: '10',
              secondaryAmount: '10',
              isFlipped: false,
              selectedFiat: FiatCurrency.usd,
            ),
          ),
        ),
        backupReminderWalletIndexProvider.overrideWithValue(null),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    // Let the active account and multisig list finish their async load.
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  testWidgets('home actions show receive and send, and swap per the flag', (tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)));
    final auth = TestLocalAuthController(authenticated: true);
    await pumpHome(tester, settings: settings, auth: auth);

    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Swap'), FeatureFlags.showSwapButton ? findsOneWidget : findsNothing);
  });

  testWidgets('intent arriving while locked stays queued and drains on unlock', (tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)));
    final auth = TestLocalAuthController(authenticated: false);
    final container = await pumpHome(tester, settings: settings, auth: auth);

    container.read(proposalIntentProvider.notifier).state = const ProposalIntent(
      multisigAddress: 'unknown-msig',
      proposalId: 1,
    );
    await tester.pump();
    expect(container.read(proposalIntentProvider), isNotNull);

    auth.setAuthenticated(true);
    await tester.pump();
    expect(container.read(proposalIntentProvider), isNull);
  });

  testWidgets('payment intent queued while locked opens the send flow bound to the active account on unlock', (
    tester,
  ) async {
    final active = makeAccount(1);
    final settings = FakeSettingsService(activeAccount: RegularAccount(active));
    final auth = TestLocalAuthController(authenticated: false);
    final container = await pumpHome(tester, settings: settings, auth: auth);

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
    expect(find.byType(InputAmountScreen), findsNothing);
    expect(container.read(paymentIntentProvider), isNotNull);

    auth.setAuthenticated(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(paymentIntentProvider), isNull);
    expect(find.byType(InputAmountScreen), findsOneWidget);
    final screen = tester.widget<InputAmountScreen>(find.byType(InputAmountScreen));
    expect((screen.strategy as RegularSendStrategy).account.accountId, active.accountId);
    expect(container.read(sendFlowActiveProvider), isTrue);
    expect(container.read(keystoneSignCacheProvider), isNull);
  });

  testWidgets('payment intent stays queued until the visual lock clears', (tester) async {
    final active = makeAccount(1);
    final settings = FakeSettingsService(activeAccount: RegularAccount(active));
    final auth = TestLocalAuthController(authenticated: true)..setVisuallyLocked(true);
    final container = await pumpHome(tester, settings: settings, auth: auth);

    container.read(paymentIntentProvider.notifier).state = PaymentIntent(to: makeAccount(9).accountId, amount: '1.5');
    await tester.pump();

    expect(container.read(paymentIntentProvider), isNotNull);
    expect(find.byType(InputAmountScreen), findsNothing);

    auth.setVisuallyLocked(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(paymentIntentProvider), isNull);
    expect(find.byType(InputAmountScreen), findsOneWidget);
    expect(container.read(sendFlowActiveProvider), isTrue);
  });

  testWidgets('intent arriving during a send flow is dropped', (tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)));
    final auth = TestLocalAuthController(authenticated: true);
    final container = await pumpHome(tester, settings: settings, auth: auth);

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
