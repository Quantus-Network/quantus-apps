import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_fee_notifier.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

void main() {
  late ProviderContainer container;
  late SendFeeNotifier notifier;

  SendFee fee(int n) => RegularFee(networkFee: BigInt.from(n));
  AsyncValue<SendFee> state() => container.read(sendFeeProvider);
  BigInt? shown() => state().value?.displayFee;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(sendFeeProvider.notifier);
  });
  tearDown(() => container.dispose());

  testWidgets('the first query runs at once and its value ends the loading state', (tester) async {
    final query = Completer<SendFee>();
    notifier.request(() => query.future);
    expect(state().isLoading, isTrue);

    query.complete(fee(1));
    await tester.pump();

    expect(shown(), BigInt.one);
  });

  testWidgets('once a fee is known, typing issues one query per pause', (tester) async {
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

    await tester.pump(SendFeeNotifier.debounce);

    expect(calls, 1);
    expect(shown(), BigInt.two);
  });

  testWidgets('a slow older query never overwrites a newer fee', (tester) async {
    final slow = Completer<SendFee>();
    notifier.request(() => slow.future);
    notifier.request(() async => fee(2));
    await tester.pump(SendFeeNotifier.debounce);
    expect(shown(), BigInt.two);

    slow.complete(fee(1));
    await tester.pump();

    expect(shown(), BigInt.two);
  });

  testWidgets('an older query still fills in while nothing newer has landed', (tester) async {
    final first = Completer<SendFee>();
    final second = Completer<SendFee>();
    notifier.request(() => first.future);
    notifier.request(() => second.future);
    await tester.pump(SendFeeNotifier.debounce);

    first.complete(fee(1));
    await tester.pump();
    expect(shown(), BigInt.one);

    second.complete(fee(2));
    await tester.pump();
    expect(shown(), BigInt.two);
  });

  testWidgets('a failed query keeps the fee already shown', (tester) async {
    notifier.request(() async => fee(1));
    await tester.pump();

    notifier.retry(() async => throw Exception('rpc down'));
    await tester.pump();

    expect(shown(), BigInt.one);
    expect(state().hasError, isFalse);
  });

  testWidgets('a failure before any fee shows the error until a retry lands', (tester) async {
    notifier.request(() async => throw Exception('rpc down'));
    await tester.pump();
    expect(state().hasError, isTrue);

    notifier.retry(() async => fee(1));
    await tester.pump();

    expect(shown(), BigInt.one);
  });

  testWidgets('reset drops the fee, cancels the pending query and ignores stale results', (tester) async {
    notifier.request(() async => fee(1));
    await tester.pump();
    final stale = Completer<SendFee>();
    var cancelledCalls = 0;
    notifier.retry(() => stale.future);
    notifier.request(() async {
      cancelledCalls++;
      return fee(3);
    });

    notifier.reset();
    expect(state().isLoading, isTrue);
    stale.complete(fee(2));
    await tester.pump(SendFeeNotifier.debounce);
    expect(state().isLoading, isTrue);
    expect(cancelledCalls, 0);

    var calls = 0;
    notifier.request(() async {
      calls++;
      return fee(4);
    });
    await tester.pump();

    expect(calls, 1);
    expect(shown(), BigInt.from(4));
  });
}
