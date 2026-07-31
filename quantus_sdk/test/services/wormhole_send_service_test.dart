import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart' show hex;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_send_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:ss58/ss58.dart';

ClaimResult _emptyResult() =>
    ClaimResult(totalWithdrawn: BigInt.zero, transfersProcessed: 0, batchesSubmitted: 0, txHashes: const []);

class _FakeUtxoService extends WormholeUtxoService {
  List<WormholeTransfer> unspent = [];

  @override
  Future<List<WormholeTransfer>> getUnspentTransfers({
    required String wormholeAddress,
    required String secretHex,
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async => unspent;
}

/// Claim flow with circuits and proving stubbed out, so tests observe the
/// live secret buffer handed to the prover.
class _StubProvingSendService extends WormholeSendService {
  _StubProvingSendService({super.utxoService});

  List<List<WormholeLeafSpend>>? capturedBatches;

  /// Copies of each leaf's secret taken at proving time — the live buffers
  /// are zeroized by the claim flow once it finishes.
  final capturedSecretCopies = <Uint8List>[];
  Object? proveError;

  @override
  Future<int> ensureCircuits(WormholeOperation op, String circuitBinsDir, ClaimProgressCallback onProgress) async => 7;

  @override
  Future<ClaimResult> proveAndSubmitBatches({
    required WormholeOperation op,
    required List<List<WormholeLeafSpend>> batches,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    Future<void> Function(int batchIndex, List<String> nullifierHexes)? onBatchSubmitted,
  }) async {
    capturedBatches = batches;
    for (final batch in batches) {
      for (final spend in batch) {
        capturedSecretCopies.add(Uint8List.fromList(spend.secret));
      }
    }
    final err = proveError;
    if (err != null) throw err;
    return _emptyResult();
  }
}

/// Regression tests for operation-local cancellation: a cancel must stick to
/// the operation it targeted (even when a second operation starts on the same
/// service before the first one finishes) and `cancel()` must not resolve
/// until the cancelled flow has actually stopped. Plus claim-flow secret
/// hygiene (M11): the decoded secret buffer must be zeroized either way.
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

  group('claim-flow secret hygiene (M11)', () {
    final destination = Address(prefix: 189, pubkey: Uint8List.fromList(List.filled(32, 0x22))).encode();
    final secretHex = '0x${'ab' * 32}';
    final transfer = WormholeTransfer(
      id: 't1',
      blockHeight: 1,
      fromId: 'from',
      toId: 'wormhole_addr',
      amount: wormholeTokenFromScaled(1000),
      toHash: '0x00',
      leafIndex: BigInt.one,
      transferCount: BigInt.one,
    );

    Future<_StubProvingSendService> runClaim({Object? proveError}) async {
      final service = _StubProvingSendService(utxoService: _FakeUtxoService()..unspent = [transfer])
        ..proveError = proveError;
      final claim = service.claimRewards(
        wormholeAddress: 'wormhole_addr',
        secretHex: secretHex,
        destinationAddress: destination,
        circuitBinsDir: '/unused',
        onProgress: (_) {},
      );
      if (proveError == null) {
        await claim;
      } else {
        await expectLater(claim, throwsA(proveError));
      }
      return service;
    }

    test('zeroizes the secret buffer once proving completes', () async {
      final service = await runClaim();
      // The prover received the real decoded secret…
      expect(service.capturedSecretCopies.single, hex.decode(secretHex.replaceFirst('0x', '')));
      // …and the live buffer was zeroized once the claim finished.
      final liveSecret = service.capturedBatches![0][0].secret;
      expect(liveSecret.every((b) => b == 0), isTrue);
    });

    test('zeroizes the secret buffer when proving fails', () async {
      final service = await runClaim(proveError: StateError('boom'));
      final liveSecret = service.capturedBatches![0][0].secret;
      expect(liveSecret.every((b) => b == 0), isTrue);
    });
  });
}
