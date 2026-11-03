import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/swap_live_activity_provider.dart';
import 'package:resonance_network_wallet/services/swap_live_activity.dart';
import 'package:resonance_network_wallet/services/swap_live_activity_client.dart';
import 'package:resonance_network_wallet/services/swap_live_activity_push.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  String format(BigInt amount, SwapToken token) => amount.toString();

  const usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
  const qtc = SwapToken(
    assetId: 'nep141:qtc.omft.near',
    symbol: 'QTC',
    network: SwapToken.quantusNetwork,
    decimals: AppConstants.decimals,
    usdPrice: 0.1,
    isQuantus: true,
  );

  final started = DateTime.utc(2026, 11, 3, 2);
  final quote = SwapQuote(
    fromToken: usdc,
    toToken: qtc,
    amountIn: BigInt.from(25000000),
    minAmountIn: BigInt.from(25000000),
    amountOut: BigInt.from(248),
    minAmountOut: BigInt.from(240),
    amountInUsd: 25,
    amountOutUsd: 24.8,
    slippageBps: 100,
    refundAddress: 'qzrefund',
    recipient: 'qzrecipient',
    deadline: started.add(const Duration(hours: 1)),
    timeEstimate: const Duration(minutes: 5),
    correlationId: 'c',
    signature: 's',
    depositAddress: 'qzdeposit',
  );

  ActiveSwap swap(
    SwapStatus status, {
    bool byHand = false,
    bool sent = false,
    bool simulated = false,
    BigInt? amountOut,
  }) => ActiveSwap(
    order: SwapOrder(quote: quote, status: status, amountOut: amountOut),
    accountId: 'qzaccount',
    accountName: 'Account 1',
    startedAt: started,
    depositByHand: byHand,
    depositSent: sent,
    simulated: simulated,
  );

  SwapLiveDecision decide(
    ActiveSwap? current, {
    bool progressVisible = false,
    bool appInForeground = true,
    DateTime? now,
  }) => decideSwapLiveActivity(
    swap: current,
    l10n: l10n,
    formatAmount: format,
    now: now ?? started.add(const Duration(minutes: 1)),
    progressVisible: progressVisible,
    appInForeground: appInForeground,
  );

  group('decideSwapLiveActivity', () {
    test('stays off the lock screen until the deposit is on its way', () {
      expect(decide(null).command, SwapLiveCommand.end);
      expect(decide(swap(SwapStatus.pendingDeposit, byHand: true)).command, SwapLiveCommand.end);
    });

    test('a sent deposit opens on Swap submitted with the quote countdown', () {
      final content = decide(swap(SwapStatus.pendingDeposit, byHand: true, sent: true)).content!;

      expect(content.phase, SwapLivePhase.submitted);
      expect(content.headline, 'Swap submitted');
      expect(content.brand, 'Swapping');
      expect(content.progress, swapLiveProgressSubmitted);
      expect(content.showProgress, isTrue);
      expect(content.chain, 'Ethereum');
      expect(content.fromAmount, quote.amountIn.toString());
      expect(content.fromSymbol, 'USDC');
      expect(content.toSymbol, 'QTC');
      expect(content.endsAt, started.add(const Duration(minutes: 5)));
      expect(content.holdsProcess, isTrue);
    });

    test('an app-sent deposit is submitted without a separate sent mark', () {
      expect(decide(swap(SwapStatus.pendingDeposit)).content!.phase, SwapLivePhase.submitted);
    });

    test('known and processing deposits advance the headline and the bar', () {
      final confirming = decide(swap(SwapStatus.knownDepositTx)).content!;
      expect(confirming.headline, 'Confirming on Ethereum');
      expect(confirming.progress, swapLiveProgressConfirming);

      final settling = decide(swap(SwapStatus.processing)).content!;
      expect(settling.headline, 'Settling on Quantus');
      expect(settling.chain, 'Ethereum');
      expect(settling.progress, swapLiveProgressSettling);
    });

    test('a paid-out amount replaces the quote once 1Click reports one', () {
      final paid = BigInt.from(250);
      final content = decide(swap(SwapStatus.processing, amountOut: paid)).content!;

      expect(content.toAmount, paid.toString());
    });

    test('a finished swap stays up only while its screen is open', () {
      expect(decide(swap(SwapStatus.success)).command, SwapLiveCommand.end);

      final content = decide(swap(SwapStatus.success), progressVisible: true).content!;
      expect(content.headline, 'Swapped');
      expect(content.brand, 'Swapping');
      expect(content.progress, swapLiveProgressSwapped);
      expect(content.showProgress, isTrue);
      expect(content.endsAt, isNull);
      expect(content.holdsProcess, isFalse);
    });

    test('a failure is shown only once the app is not in front', () {
      expect(decide(swap(SwapStatus.failed)).command, SwapLiveCommand.end);

      final failed = decide(swap(SwapStatus.failed), appInForeground: false).content!;
      expect(failed.headline, 'Swap Failed');
      expect(failed.brand, 'Swap');
      expect(failed.showProgress, isFalse);
      expect(failed.holdsProcess, isFalse);

      final refunded = decide(swap(SwapStatus.refunded), appInForeground: false).content!;
      expect(refunded.headline, 'Refunded');

      final incomplete = decide(swap(SwapStatus.incompleteDeposit), appInForeground: false).content!;
      expect(incomplete.headline, 'Deposit Too Small');
      expect(incomplete.holdsProcess, isTrue);
    });
  });

  test('registration body is the display contract Senoti echoes', () {
    final content = decide(swap(SwapStatus.knownDepositTx)).content!;
    final body = swapLiveActivityRegistrationBody(token: 'abc', platform: 'ios', content: content);

    expect(body['activity_token'], 'abc');
    expect(body['platform'], 'ios');
    expect(body['deposit_address'], 'qzdeposit');
    expect(body['phase'], 'confirming');
    expect(body['chain'], 'Ethereum');
    expect(body['labels'], containsPair('confirming', 'Confirming on Ethereum'));
    expect(body['labels'], containsPair('settling', 'Settling on Quantus'));
    expect(body['content_state'], containsPair('headline', 'Confirming on Ethereum'));
    expect(body['content_state'], containsPair('phase', 'confirming'));
    expect(body['progress'], containsPair('settling', swapLiveProgressSettling));
    expect(body.containsKey('recipient'), isFalse);
  });

  test('Senoti registration accepts 202 and rejects anything else', () async {
    final content = decide(swap(SwapStatus.pendingDeposit)).content!;
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/swap-activities'));
      expect(jsonDecode(request.body), containsPair('activity_token', 'abc'));
      return http.Response('', request.method == 'POST' ? 202 : 500);
    });
    final push = SwapLiveActivityPush(client: client, endpoint: 'https://snt.test/api');

    await push.register(token: 'abc', platform: 'ios', content: content);
    expect(push.unregister('abc'), throwsException);
  });

  group('SwapLiveActivityController', () {
    late _Client card;
    late _Registrar registrar;
    late ActiveSwap? current;
    late DateTime now;
    late bool visible;
    late SwapLiveActivityController controller;

    setUp(() {
      card = _Client();
      registrar = _Registrar();
      current = swap(SwapStatus.pendingDeposit);
      now = started;
      visible = true;
      controller = SwapLiveActivityController(
        client: card,
        push: registrar,
        devicePushPlatform: 'android',
        deviceToken: () async => 'fcm-token',
        snapshot: () =>
            SwapLiveSnapshot(swap: current, l10n: l10n, formatAmount: format, now: now, progressVisible: visible),
      );
    });

    tearDown(() => controller.dispose());

    test('shows once, then only again once the refresh interval has passed', () async {
      await controller.sync();
      expect(card.shown, hasLength(1));
      expect(card.shown.single['headline'], 'Swap submitted');
      expect(registrar.calls.single.$1, 'fcm-token');

      now = now.add(const Duration(seconds: 10));
      await controller.sync();
      expect(card.shown, hasLength(1));

      now = now.add(swapLiveRefreshAfter);
      await controller.sync();
      expect(card.shown, hasLength(2));
      expect(registrar.calls, hasLength(1));
    });

    test('a dismissed card is not put back for the same swap', () async {
      await controller.sync();
      card.emit(SwapLiveDismissed());
      await pumpEventQueue();

      expect(card.ended, greaterThan(0));
      final shownAfterDismiss = card.shown.length;
      await controller.sync();
      expect(card.shown, hasLength(shownAfterDismiss));
    });

    test('leaving the finished screen removes the card', () async {
      current = swap(SwapStatus.success);
      await controller.sync();
      expect(card.shown.single['phase'], 'swapped');

      visible = false;
      await controller.sync();
      expect(card.ended, 1);
    });

    test('a simulated swap is not registered', () async {
      current = swap(SwapStatus.pendingDeposit, simulated: true);
      await controller.sync();

      expect(card.shown, hasLength(1));
      expect(registrar.calls, isEmpty);
    });

    test('an activity token is registered for iOS push', () async {
      await controller.sync();
      card.emit(SwapLiveToken('activity-token'));
      await pumpEventQueue();

      expect(registrar.calls.map((call) => (call.$1, call.$2)), contains(('activity-token', 'ios')));
    });
  });
}

class _Client implements SwapLiveActivityClient {
  final shown = <Map<String, Object?>>[];
  var ended = 0;
  final _events = StreamController<SwapLiveActivityEvent>.broadcast();

  void emit(SwapLiveActivityEvent event) => _events.add(event);

  @override
  Stream<SwapLiveActivityEvent> get events => _events.stream;

  @override
  Future<void> show(Map<String, Object?> payload) async => shown.add(payload);

  @override
  Future<void> end() async => ended++;
}

class _Registrar implements SwapLiveActivityRegistrar {
  final calls = <(String, String, SwapLivePhase)>[];

  @override
  Future<void> register({
    required String token,
    required String platform,
    required SwapLiveActivityContent content,
  }) async => calls.add((token, platform, content.phase));

  @override
  Future<void> unregister(String token) async {}
}
