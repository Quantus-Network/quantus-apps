import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/swap_live_activity_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  const usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
  const qtc = SwapToken(
    assetId: 'nep141:qtc.omft.near',
    symbol: 'QTC',
    network: SwapToken.quantusNetwork,
    decimals: AppConstants.decimals,
    usdPrice: 0.1,
    isQuantus: true,
  );

  testWidgets('the swap on screen is the last progress route opened, and leaving one gives back the one below', (
    tester,
  ) async {
    final account = makeAccount(1);
    final started = DateTime.utc(2026, 11, 3);
    ActiveSwap swap(String depositAddress) => ActiveSwap(
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
          recipient: '0x${'ab' * 20}',
          deadline: started.add(const Duration(hours: 1)),
          timeEstimate: const Duration(minutes: 1),
          correlationId: 'c',
          signature: 's',
          depositAddress: depositAddress,
        ),
        status: SwapStatus.success,
        amountOut: BigInt.from(100000),
      ),
      accountId: account.accountId,
      accountName: account.name,
      startedAt: started,
      settledAt: started.add(const Duration(minutes: 1)),
      depositByHand: false,
      simulated: true,
    );
    final settings = FakeSettingsService(
      activeAccount: RegularAccount(account),
      activeSwaps: [swap('qzdeposit'), swap('qzother')],
    );

    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(context, SwapProgressScreen.route('qzdeposit', account: account)),
          child: const Text('open'),
        ),
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        l10nProvider.overrideWithValue(l10n),
        isOnlineProvider.overrideWithValue(true),
      ],
    );
    final container = ProviderScope.containerOf(tester.element(find.text('open')));
    Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(container.read(swapProgressVisibleProvider), isEmpty);

    await tester.tap(find.text('open'));
    await settle();
    expect(container.read(swapProgressVisibleProvider), ['qzdeposit']);

    unawaited(
      Navigator.of(
        tester.element(find.byType(SwapProgressScreen)),
      ).push(SwapProgressScreen.route('qzother', account: account)),
    );
    await settle();
    expect(container.read(swapProgressVisibleProvider), ['qzdeposit', 'qzother']);

    await tester.tap(find.byType(AppBackButton));
    await settle();
    expect(find.byType(SwapProgressScreen), findsOneWidget);
    expect(container.read(swapProgressVisibleProvider), ['qzdeposit']);

    await tester.tap(find.byType(AppBackButton));
    await settle();
    expect(find.byType(SwapProgressScreen), findsNothing);
    expect(container.read(swapProgressVisibleProvider), isEmpty);
  });
}
