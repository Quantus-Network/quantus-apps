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

  List<WormholeBatchSpend>? capturedBatches;

  /// Copies of each leaf's secret taken at proving time — the live buffers
  /// are zeroized by the claim flow once it finishes.
  final capturedSecretCopies = <Uint8List>[];
  Object? proveError;

  @override
  Future<WormholeBatchShape> ensureCircuits(
    WormholeOperation op,
    String circuitBinsDir,
    ClaimProgressCallback onProgress,
  ) async => (numLeafProofs: 9, numExitSlots: 32);

  @override
  Future<ClaimResult> proveAndSubmitBatches({
    required WormholeOperation op,
    required List<WormholeBatchSpend> batches,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    Future<void> Function(int batchIndex, List<String> nullifierHexes)? onBatchSubmitted,
  }) async {
    capturedBatches = batches;
    for (final batch in batches) {
      for (final burn in batch.burns) {
        capturedSecretCopies.add(Uint8List.fromList(burn.secret));
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
      timestamp: DateTime(2026),
      fromId: 'from',
      toId: 'wormhole_addr',
      amount: wormholeTokenFromScaled(1000),
      toHash: '0x00',
      leafIndex: BigInt.one,
      transferCount: BigInt.one,
      extrinsicId: '',
      viaWormhole: false,
    );

    Future<_StubProvingSendService> runClaim({Object? proveError, List<WormholeTransfer>? transfers}) async {
      final service = _StubProvingSendService(utxoService: _FakeUtxoService()..unspent = transfers ?? [transfer])
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
      final liveSecret = service.capturedBatches![0].burns[0].secret;
      expect(liveSecret.every((b) => b == 0), isTrue);
    });

    test('zeroizes the secret buffer when proving fails', () async {
      final service = await runClaim(proveError: StateError('boom'));
      final liveSecret = service.capturedBatches![0].burns[0].secret;
      expect(liveSecret.every((b) => b == 0), isTrue);
    });

    test('pays each private batch its net in a single exit to the destination', () async {
      final rewards = [
        for (var i = 0; i < 12; i++)
          WormholeTransfer(
            id: 't$i',
            blockHeight: i,
            timestamp: DateTime(2026),
            fromId: 'from',
            toId: 'wormhole_addr',
            amount: wormholeTokenFromScaled(50),
            toHash: '0x00',
            leafIndex: BigInt.from(i + 1),
            transferCount: BigInt.one,
            extrinsicId: '',
            viaWormhole: false,
          ),
      ];

      final service = await runClaim(transfers: rewards);
      final batches = service.capturedBatches!;
      expect(batches.map((b) => b.burns.length), [9, 3]);
      for (final batch in batches) {
        expect(batch.exits.single.account, Address.decode(destination).pubkey);
        expect(batch.exits.single.returnsToSender, isFalse);
      }
      expect(batches.map((b) => b.exits.single.amountScaled), [449, 149]);
    });
  });

  group('sendSpends validation', () {
    final account = Uint8List.fromList(List.filled(32, 0x22));
    WormholeBurn burn(int scaled) => WormholeBurn(
      transfer: WormholeTransfer(
        id: 't$scaled',
        blockHeight: 1,
        timestamp: DateTime(2026),
        fromId: 'from',
        toId: 'to',
        amount: wormholeTokenFromScaled(scaled),
        toHash: '0x00',
        leafIndex: BigInt.from(scaled),
        transferCount: BigInt.one,
        extrinsicId: '',
        viaWormhole: false,
      ),
      secret: Uint8List(32),
    );
    WormholeExit exit(int scaled) => WormholeExit(account: account, amountScaled: scaled);

    Future<void> send(List<WormholeBatchSpend> batches) =>
        _StubProvingSendService().sendSpends(batches: batches, circuitBinsDir: '/unused', onProgress: (_) {});

    test('accepts exits within the batch net and the slot budget', () async {
      await send([
        WormholeBatchSpend(burns: [burn(1000), burn(500)], exits: [exit(1000), exit(499)]),
      ]);
    });

    test('rejects exits above the batch net', () async {
      await expectLater(
        send([
          WormholeBatchSpend(burns: [burn(1000)], exits: [exit(1000)]),
        ]),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exceed net input'))),
      );
    });

    test('rejects more burns than leaf proofs or more exits than slots', () async {
      await expectLater(
        send([
          WormholeBatchSpend(burns: List.generate(11, (i) => burn(100 + i)), exits: [exit(1)]),
        ]),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('aggregation arity'))),
      );
      await expectLater(
        send([
          WormholeBatchSpend(burns: [burn(100000)], exits: List.generate(33, (_) => exit(1))),
        ]),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exit-slot count'))),
      );
    });

    test('rejects a batch with no exits or no burns', () async {
      await expectLater(
        send([
          WormholeBatchSpend(burns: [burn(1000)], exits: const []),
        ]),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        send([
          WormholeBatchSpend(burns: const [], exits: [exit(1)]),
        ]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
