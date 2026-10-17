import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_activity_row.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required FakeSettingsService settings,
    required TestLocalAuthController auth,
    bool enableSwap = true,
    bool enableSwapAndroid = true,
    bool geoNearAllowed = true,
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
            CurrencyDisplayState(primaryAmount: '10', secondaryAmount: '10', selectedFiat: FiatCurrency.usd),
          ),
        ),
        backupReminderWalletIndexProvider.overrideWithValue(null),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
        substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
        remoteConfigProvider.overrideWith((ref) {
          final config = RemoteConfigModel.fromJson({
            'enableSwap': enableSwap,
            'enableSwapAndroid': enableSwapAndroid,
            'geoNearAllowed': geoNearAllowed,
          });
          return RemoteConfigNotifier(FakeRemoteConfigService(config, remote: config));
        }),
      ],
    );
    // Let the active account and multisig list finish their async load, then
    // the remote config sync that grants the location verdict.
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  /// A swap out of [account] into USDC, as the app follows it, [age] old;
  /// [byHand], a swap into QTC whose deposit is still to be sent.
  ActiveSwap swapOf(
    Account account,
    SwapStatus status, {
    Duration age = const Duration(minutes: 3, seconds: 7),
    bool byHand = false,
  }) {
    const usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
    const qtc = SwapToken(
      assetId: 'nep141:qtc.omft.near',
      symbol: 'QTC',
      network: SwapToken.quantusNetwork,
      decimals: AppConstants.decimals,
      usdPrice: 0.1,
      isQuantus: true,
    );
    final now = clock.now();
    return ActiveSwap(
      order: SwapOrder(
        quote: SwapQuote(
          fromToken: qtc,
          toToken: usdc,
          amountIn: BigInt.from(10).pow(AppConstants.decimals),
          minAmountIn: BigInt.from(10).pow(AppConstants.decimals),
          amountOut: BigInt.from(100000),
          minAmountOut: BigInt.from(99000),
          amountInUsd: 0.1,
          amountOutUsd: 0.1,
          slippageBps: 100,
          refundAddress: account.accountId,
          recipient: '0xrecipient',
          deadline: now.add(const Duration(minutes: 20)),
          timeEstimate: const Duration(minutes: 1),
          correlationId: 'c',
          signature: 's',
          depositAddress: 'qzdeposit',
        ),
        status: status,
      ),
      accountId: account.accountId,
      accountName: account.name,
      startedAt: now.subtract(age),
      settledAt: status.isFinal ? now : null,
      depositByHand: byHand,
      depositTxHash: byHand ? null : '0xtx',
    );
  }

  FakeSettingsService settingsFollowing(Account account, ActiveSwap swap) =>
      FakeSettingsService(activeAccount: RegularAccount(account), activeSwap: swap);

  Color dotColor(WidgetTester tester, int index) {
    final dots = find.descendant(of: find.byType(SwapProgressDots), matching: find.byType(Container));
    return (tester.widget<Container>(dots.at(index)).decoration as BoxDecoration).color!;
  }

  testWidgets('a swap whose deposit is with 1Click is pinned above the activity and opens from there', (tester) async {
    final account = makeAccount(1);
    final settings = settingsFollowing(account, swapOf(account, SwapStatus.processing));
    await pumpHome(tester, settings: settings, auth: TestLocalAuthController(authenticated: true));

    expect(find.text('1 QTC → 0.1 USDC'), findsOneWidget);
    expect(find.text('Swapping'), findsOneWidget);
    expect(find.text('3:07'), findsOneWidget);
    final colors = tester.element(find.byType(SwapActivityRow)).colorsV3;
    expect(
      [for (var i = 0; i < swapStepCount; i++) dotColor(tester, i)],
      [colors.semanticSage, colors.semanticSage, colors.semanticSage, colors.bgSurface2],
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3:08'), findsOneWidget);

    await tester.tap(find.text('3:08'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SwapProgressScreen), findsOneWidget);
    expect(find.byType(SwapScreen), findsNothing);
  });

  for (final (what, status, byHand, title) in [
    ('a swap whose deposit is still to be sent', SwapStatus.pendingDeposit, true, 'Send Your Deposit'),
    ('a settled swap', SwapStatus.refunded, false, 'Swap Failed'),
  ]) {
    testWidgets('$what is not pinned; the swap button opens it, even where swaps are off', (tester) async {
      final account = makeAccount(1);
      final settings = settingsFollowing(account, swapOf(account, status, byHand: byHand));
      await pumpHome(tester, settings: settings, auth: TestLocalAuthController(authenticated: true), enableSwap: false);

      expect(find.byType(SwapProgressDots), findsNothing);
      expect(find.text('3:07'), findsNothing);
      await tester.tap(find.text('Swap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SwapProgressScreen), findsOneWidget);
      expect(find.text(title), findsOneWidget);
    });
  }

  testWidgets('a swap whose hand deposit 1Click has seen is pinned, on a multisig home too', (tester) async {
    final account = makeAccount(1);
    final settings = settingsFollowing(account, swapOf(account, SwapStatus.knownDepositTx, byHand: true))
      ..activeAccount = MultisigDisplayAccount(makeMultisigAccount())
      ..multisigs = [makeMultisigAccount()];
    await pumpHome(tester, settings: settings, auth: TestLocalAuthController(authenticated: true));

    expect(find.text('1 QTC → 0.1 USDC'), findsOneWidget);
    expect(find.text('Confirming on Quantus'), findsOneWidget);
    await tester.tap(find.text('3:07'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SwapProgressScreen), findsOneWidget);
  });

  // The swap being followed belongs to the wallet, not the selected account:
  // it shows and opens from any home, while only an account with a key here
  // may start the next one.
  final entrusted = EntrustedAccount(
    parentAccountId: makeAccount(1).accountId,
    index: 0,
    name: 'Entrusted',
    accountId: 'qzentrusted${'x' * 40}',
  );
  for (final (kind, active) in [
    ('multisig', MultisigDisplayAccount(makeMultisigAccount())),
    ('entrusted', EntrustedDisplayAccount(entrusted)),
  ]) {
    testWidgets('a swap being followed shows on a $kind home and opens, though no swap can start there', (
      tester,
    ) async {
      final account = makeAccount(1);
      final settings = settingsFollowing(account, swapOf(account, SwapStatus.failed))
        ..activeAccount = active
        ..multisigs = [makeMultisigAccount()];
      await pumpHome(tester, settings: settings, auth: TestLocalAuthController(authenticated: true));

      expect(find.text('Send'), findsNothing);
      expect(find.text('Propose'), kind == 'multisig' ? findsOneWidget : findsNothing);
      expect(find.byType(SwapProgressDots), findsNothing);
      expect(find.text('Swap'), findsOneWidget);

      await tester.tap(find.text('Swap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SwapProgressScreen), findsOneWidget);
      QuantusButton button(String label) =>
          tester.widget<QuantusButton>(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));
      expect(button('Start a New Swap').isDisabled, isTrue);
      expect(find.text('Contact Support'), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SwapProgressScreen), findsNothing);
    });
  }

  // Each platform follows its own flag; the other platform's flag is set to
  // the opposite so it visibly has no say.
  for (final (enabled, geoNearAllowed) in [(true, true), (false, true), (true, false)]) {
    testWidgets(
      'home actions show receive and send, and swap when the platform swap flag is $enabled and the location allows NEAR is $geoNearAllowed',
      (tester) async {
        final android = defaultTargetPlatform == TargetPlatform.android;
        final settings = FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)));
        final auth = TestLocalAuthController(authenticated: true);
        await pumpHome(
          tester,
          settings: settings,
          auth: auth,
          enableSwap: android ? !enabled : enabled,
          enableSwapAndroid: android ? enabled : !enabled,
          geoNearAllowed: geoNearAllowed,
        );

        expect(find.text('Receive'), findsOneWidget);
        expect(find.text('Send'), findsOneWidget);
        expect(find.text('Swap'), enabled && geoNearAllowed ? findsOneWidget : findsNothing);
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
    );
  }

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
