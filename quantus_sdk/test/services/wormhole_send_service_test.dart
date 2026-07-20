import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_send_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

ClaimResult _emptyResult() => ClaimResult(
  totalWithdrawn: BigInt.zero,
  transfersProcessed: 0,
  batchesSubmitted: 0,
  txHashes: const [],
);

/// Regression tests for operation-local cancellation: a cancel must stick to
/// the operation it targeted (even when a second operation starts on the same
/// service before the first one finishes) and `cancel()` must not resolve
/// until the cancelled flow has actually stopped.
void main() {
  test('cancel() only affects the in-flight operation and awaits its true completion', () async {
    final service = WormholeSendService();

    final op1Started = Completer<void>();
    final op1Release = Completer<void>();
    WormholeOperation? op1Context;
    final op1Future = service.runOperation(null, (op) async {
      op1Context = op;
      op1Started.complete();
      // Simulates an unresolved proof: the flow is stuck in work it cannot
      // abandon until it reaches the next checkpoint.
      await op1Release.future;
      op.checkCancelled();
      return _emptyResult();
    });
    await op1Started.future;

    final cancelFuture = service.cancel();
    var cancelResolved = false;
    unawaited(cancelFuture.whenComplete(() => cancelResolved = true));

    // A second operation starting on the same service must neither un-cancel
    // the first flow nor inherit its cancellation.
    WormholeOperation? op2Context;
    final op2Result = await service.runOperation(null, (op) async {
      op2Context = op;
      op.checkCancelled();
      return _emptyResult();
    });
    expect(op2Result.batchesSubmitted, 0);
    expect(op2Context!.isCancelled, isFalse);
    expect(op1Context!.isCancelled, isTrue);

    // cancel() targeted op1, so it must still be waiting for op1 — not
    // resolved just because op2 came and went.
    await Future<void>.delayed(Duration.zero);
    expect(cancelResolved, isFalse);

    op1Release.complete();
    await expectLater(op1Future, throwsA(isA<ClaimCancelled>()));
    await cancelFuture;
    expect(cancelResolved, isTrue);
  });

  test('cancel() is a no-op when nothing is running', () async {
    await WormholeSendService().cancel();
  });

  test('a flow interrupted by the UTXO service surfaces as ClaimCancelled', () async {
    final service = WormholeSendService();
    final future = service.runOperation(null, (op) async => throw const WormholeOperationCancelled());
    await expectLater(future, throwsA(isA<ClaimCancelled>()));
  });

  test('checkCancelled before cancel does not throw', () async {
    final service = WormholeSendService();
    final result = await service.runOperation(null, (op) async {
      op.checkCancelled();
      return _emptyResult();
    });
    expect(result.cancelled, isFalse);
  });
}
