import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/swap_live_activity_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.quantus/swap_live_activity');
  final calls = <MethodCall>[];

  const shownKey = 'qzdeposit|1730000000000';
  const completion = <String, String>{
    'type': 'swap_live_activity',
    'phase': 'swapped',
    'failure': '',
    'headline': 'Swapped',
    'brand': 'Swapping',
    'idleBrand': 'Swap',
    'fromAmount': '25',
    'fromSymbol': 'USDC',
    'toAmount': '248',
    'toSymbol': 'QTC',
    'chain': 'Ethereum',
    'fromLabel': 'From',
    'toLabel': 'To',
    'chainLabel': 'Chain',
    'openToCheck': 'Open to check',
    'agoLabel': 'ago',
    'overdueLabel': 'Taking longer',
    'progress': '1.0',
    'showProgress': 'false',
    'endsAt': '',
    'updatedAt': '1730000060000',
    'staleAt': '1730000180000',
    'holdsProcess': 'false',
    'key': shownKey,
    'channelName': 'Swap progress',
  };

  Map<String, Object?>? cardResponse = {'key': shownKey, 'dismissedKey': null};

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    cardResponse = {'key': shownKey, 'dismissedKey': null};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'card') return cardResponse;
      if (call.method == 'show' || call.method == 'replace') {
        final args = call.arguments as Map;
        cardResponse = {
          'key': args['key'],
          'dismissedKey': cardResponse?['dismissedKey'],
          'updatedAt': args['updatedAt'],
          'phase': args['phase'],
          'failure': args['failure'],
        };
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  void expectCompletion(MethodCall call) {
    expect(call.method, 'replace');
    final args = call.arguments as Map;
    expect(args['phase'], 'swapped');
    expect(args['headline'], 'Swapped');
    expect(args['key'], shownKey);
    expect(args['progress'], 1.0);
    expect(args['showProgress'], isFalse);
    expect(args['holdsProcess'], isFalse);
    expect(args['endsAt'], isNull);
    expect(args['fromAmount'], '25');
    expect(args['overdueLabel'], 'Taking longer');
    expect(args['updatedAt'], 1730000060000);
  }

  test('background handler applies a swap completion to the matching card', () async {
    await firebaseMessagingBackgroundHandler(const RemoteMessage(messageId: 'swap-done', data: completion));

    expectCompletion(calls.last);
    expect(calls.where((call) => call.method == 'replace'), hasLength(1));
  });

  test('a wrapped content_state is the same completion payload', () async {
    final wrapped = <String, String>{
      'type': 'swap_live_activity',
      'content_state': jsonEncode(Map<String, String>.from(completion)..remove('type')),
    };

    await deliverSwapLiveActivityPush(wrapped);

    expectCompletion(calls.last);
  });

  test('a dismissed card is left alone', () async {
    cardResponse = {'key': shownKey, 'dismissedKey': shownKey};

    await firebaseMessagingBackgroundHandler(const RemoteMessage(data: completion));

    expect(calls.where((call) => call.method == 'replace'), isEmpty);
  });

  test('a different swap is left alone', () async {
    cardResponse = {'key': 'other|1', 'dismissedKey': null};

    await firebaseMessagingBackgroundHandler(const RemoteMessage(data: completion));

    expect(calls.where((call) => call.method == 'replace'), isEmpty);
  });

  Map<String, String> phaseAt(String phase, String updatedAt, {required String holdsProcess}) => {
    ...completion,
    'phase': phase,
    'headline': phase,
    'updatedAt': updatedAt,
    'holdsProcess': holdsProcess,
    'showProgress': holdsProcess,
  };

  test('a delayed settling update does not replace a swapped card', () async {
    await deliverSwapLiveActivityPush(phaseAt('swapped', '2000', holdsProcess: 'false'));
    await deliverSwapLiveActivityPush(phaseAt('settling', '1000', holdsProcess: 'true'));

    final shown = calls.where((call) => call.method == 'replace').toList();
    expect(shown, hasLength(1));
    expect(shown.single.arguments['phase'], 'swapped');
    expect(shown.single.arguments['holdsProcess'], isFalse);
  });

  test('a newer settling update does not reopen a swapped card', () async {
    await deliverSwapLiveActivityPush(phaseAt('swapped', '2000', holdsProcess: 'false'));
    await deliverSwapLiveActivityPush(phaseAt('settling', '3000', holdsProcess: 'true'));

    final shown = calls.where((call) => call.method == 'replace').toList();
    expect(shown, hasLength(1));
    expect(shown.single.arguments['phase'], 'swapped');
    expect(shown.single.arguments['holdsProcess'], isFalse);
  });

  test('a newer swapped update still replaces settling', () async {
    await deliverSwapLiveActivityPush(phaseAt('settling', '1000', holdsProcess: 'true'));
    await deliverSwapLiveActivityPush(phaseAt('swapped', '2000', holdsProcess: 'false'));

    final shown = calls.where((call) => call.method == 'replace').toList();
    expect(shown, hasLength(2));
    expect(shown.last.arguments['phase'], 'swapped');
    expect(shown.last.arguments['holdsProcess'], isFalse);
  });

  test('a refunded card does not return to settling', () async {
    await deliverSwapLiveActivityPush({...phaseAt('failed', '2000', holdsProcess: 'false'), 'failure': 'refunded'});
    await deliverSwapLiveActivityPush(phaseAt('settling', '3000', holdsProcess: 'true'));

    final shown = calls.where((call) => call.method == 'replace').toList();
    expect(shown, hasLength(1));
    expect(shown.single.arguments['phase'], 'failed');
    expect(shown.single.arguments['failure'], 'refunded');
  });

  test('an incomplete deposit still accepts a newer settling update', () async {
    await deliverSwapLiveActivityPush({...phaseAt('failed', '1000', holdsProcess: 'true'), 'failure': 'incomplete'});
    await deliverSwapLiveActivityPush(phaseAt('settling', '2000', holdsProcess: 'true'));

    final shown = calls.where((call) => call.method == 'replace').toList();
    expect(shown, hasLength(2));
    expect(shown.last.arguments['phase'], 'settling');
    expect(shown.last.arguments['holdsProcess'], isTrue);
  });

  test('a push without a revision does not replace the card', () async {
    await deliverSwapLiveActivityPush(phaseAt('settling', '1000', holdsProcess: 'true'));
    await deliverSwapLiveActivityPush({...phaseAt('swapped', '2000', holdsProcess: 'false'), 'updatedAt': ''});

    final shown = calls.where((call) => call.method == 'replace').toList();
    expect(shown, hasLength(1));
    expect(shown.single.arguments['phase'], 'settling');
  });

  test('a push does not create a card', () async {
    cardResponse = null;

    await firebaseMessagingBackgroundHandler(const RemoteMessage(data: completion));

    expect(calls.where((call) => call.method == 'replace'), isEmpty);
  });

  test('a transfer push is not a swap card update', () async {
    await firebaseMessagingBackgroundHandler(const RemoteMessage(data: {'type': 'TRANSFER', 'extrinsicHash': '0xabc'}));

    expect(calls, isEmpty);
  });

  test('foreground uses the same update and skips the transaction notification', () async {
    var transactions = 0;
    var refreshes = 0;

    await handleForegroundFcmMessage(
      const RemoteMessage(messageId: 'swap-front', data: completion),
      refreshHistory: () async => refreshes++,
      showTransactionNotification: (_) async => transactions++,
    );
    final foreground = calls.where((call) => call.method == 'replace').single;
    calls.clear();

    await firebaseMessagingBackgroundHandler(const RemoteMessage(data: completion));
    final background = calls.where((call) => call.method == 'replace').single;

    expectCompletion(foreground);
    expect(foreground.arguments, background.arguments);
    expect(transactions, 0);
    expect(refreshes, 1);
  });

  test('foreground still shows a transaction notification for a transfer', () async {
    var transactions = 0;

    await handleForegroundFcmMessage(
      const RemoteMessage(data: {'type': 'TRANSFER', 'extrinsicHash': '0xabc'}),
      refreshHistory: () async {},
      showTransactionNotification: (_) async => transactions++,
    );

    expect(transactions, 1);
    expect(calls, isEmpty);
  });

  test('iOS does not apply the Android data message to the card channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await firebaseMessagingBackgroundHandler(const RemoteMessage(data: completion));

    expect(calls, isEmpty);
  });
}
