import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_fee_notifier.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

void main() {
  late ProviderContainer container;
  late SendFeeNotifier notifier;

  SendFee fee(int n) => RegularFee(networkFee: BigInt.from(n));
  SendFeeState state() => container.read(sendFeeProvider);
  BigInt? shown() => state().fee?.displayFee;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(sendFeeProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('retry before any request fails early', () {
    expect(notifier.retry, throwsStateError);
  });

  testWidgets('the first query runs at once and its value settles the fee', (tester) async {
    final query = Completer<SendFee>();
    notifier.request(() => query.future);
    expect(state().fee, isNull);
    expect(state().pending, isTrue);

    query.complete(fee(1));
    await tester.pump();

    expect(shown(), BigInt.one);
    expect(state().settled, isTrue);
  });

  testWidgets('once a fee is known, typing marks it an estimate and issues one query per pause', (tester) async {
    notifier.request(() async => fee(1));
    await tester.pump();

    var calls = 0;
    for (var i = 0; i < 3; i++) {
      notifier.request(() async {
        calls++;
        return fee(2);
      });
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(calls, 0);
    expect(shown(), BigInt.one);
    expect(state().pending, isTrue);
    expect(state().settled, isFalse);

    await tester.pump(SendFeeNotifier.debounce);

    expect(calls, 1);
    expect(shown(), BigInt.two);
    expect(state().settled, isTrue);
  });

  testWidgets('an immediate request skips the debounce', (tester) async {
    notifier.request(() async => fee(1));
    await tester.pump();

    var calls = 0;
    notifier.request(() async {
      calls++;
      return fee(2);
    }, immediate: true);
    await tester.pump();

    expect(calls, 1);
    expect(shown(), BigInt.two);
    expect(state().settled, isTrue);
  });

  testWidgets('a slow older query never overwrites a newer fee', (tester) async {
    final slow = Completer<SendFee>();
    notifier.request(() => slow.future);
    notifier.request(() async => fee(2));
    await tester.pump(SendFeeNotifier.debounce);
    expect(shown(), BigInt.two);
    expect(state().settled, isTrue);

    slow.complete(fee(1));
    await tester.pump();

    expect(shown(), BigInt.two);
    expect(state().settled, isTrue);
  });

  testWidgets('an older query fills in as an estimate while a newer one is in flight', (tester) async {
    final first = Completer<SendFee>();
    final second = Completer<SendFee>();
    notifier.request(() => first.future);
    notifier.request(() => second.future);
    await tester.pump(SendFeeNotifier.debounce);

    first.complete(fee(1));
    await tester.pump();
    expect(shown(), BigInt.one);
    expect(state().pending, isTrue);

    second.complete(fee(2));
    await tester.pump();
    expect(shown(), BigInt.two);
    expect(state().settled, isTrue);
  });

  testWidgets('a failed refinement keeps the fee, flags it, and retry re-runs it', (tester) async {
    notifier.request(() async => fee(1));
    await tester.pump();

    var fail = true;
    var calls = 0;
    notifier.request(() async {
      calls++;
      if (fail) throw Exception('rpc down');
      return fee(2);
    }, immediate: true);
    await tester.pump();

    expect(shown(), BigInt.one);
    expect(state().failed, isTrue);
    expect(state().settled, isFalse);

    fail = false;
    notifier.retry();
    await tester.pump();

    expect(calls, 2);
    expect(shown(), BigInt.two);
    expect(state().settled, isTrue);
  });

  testWidgets('a failure before any fee is an error until a retry lands', (tester) async {
    var fail = true;
    notifier.request(() async {
      if (fail) throw Exception('rpc down');
      return fee(1);
    });
    await tester.pump();
    expect(state().fee, isNull);
    expect(state().failed, isTrue);
    expect(state().pending, isFalse);

    fail = false;
    notifier.retry();
    await tester.pump();

    expect(shown(), BigInt.one);
    expect(state().settled, isTrue);
  });

  testWidgets('a newer failure survives an older success', (tester) async {
    final slow = Completer<SendFee>();
    notifier.request(() => slow.future);
    notifier.request(() async => throw Exception('rpc down'), immediate: true);
    await tester.pump();
    expect(state().failed, isTrue);
    expect(state().pending, isFalse);

    slow.complete(fee(1));
    await tester.pump();

    expect(shown(), BigInt.one);
    expect(state().failed, isTrue);
    expect(state().pending, isFalse);
    expect(state().settled, isFalse);
  });

  testWidgets('a failure of a superseded query is ignored', (tester) async {
    notifier.request(() async => fee(1));
    await tester.pump();
    final slow = Completer<SendFee>();
    notifier.request(() => slow.future, immediate: true);
    notifier.request(() async => fee(3));
    await tester.pump(SendFeeNotifier.debounce);
    expect(shown(), BigInt.from(3));

    slow.completeError(Exception('late failure'));
    await tester.pump();

    expect(shown(), BigInt.from(3));
    expect(state().settled, isTrue);
  });

  testWidgets('reset drops the fee, cancels the pending query and ignores stale results', (tester) async {
    notifier.request(() async => fee(1));
    await tester.pump();
    final stale = Completer<SendFee>();
    var cancelledCalls = 0;
    notifier.request(() => stale.future, immediate: true);
    notifier.request(() async {
      cancelledCalls++;
      return fee(3);
    });

    notifier.reset();
    expect(state(), const SendFeeState());
    stale.complete(fee(2));
    await tester.pump(SendFeeNotifier.debounce);
    expect(state().fee, isNull);
    expect(cancelledCalls, 0);

    var calls = 0;
    notifier.request(() async {
      calls++;
      return fee(4);
    });
    await tester.pump();

    expect(calls, 1);
    expect(shown(), BigInt.from(4));
    expect(state().settled, isTrue);
  });
}
