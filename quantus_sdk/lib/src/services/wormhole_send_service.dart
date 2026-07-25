import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:polkadart/scale_codec.dart' show ByteOutput, CompactCodec;
import 'package:quantus_sdk/generated/planck/pallets/wormhole.dart' as wormhole_pallet;
import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole_ffi;
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart' show getAccountId32;
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

class ClaimProgressItem {
  final int step;
  final String title;
  final int completed;
  final int? total;

  const ClaimProgressItem({required this.step, required this.title, required this.completed, this.total});
}

typedef ClaimProgressCallback = void Function(ClaimProgressItem progress);

class ClaimResult {
  final BigInt totalWithdrawn;
  final int transfersProcessed;
  final int batchesSubmitted;
  final List<String> txHashes;

  /// True when the operation was cancelled after one or more batches had
  /// already been submitted: the listed [txHashes] have paid out, the
  /// remaining batches were not attempted. A cancel before any submission
  /// surfaces as [ClaimCancelled] instead.
  final bool cancelled;

  const ClaimResult({
    required this.totalWithdrawn,
    required this.transfersProcessed,
    required this.batchesSubmitted,
    required this.txHashes,
    this.cancelled = false,
  });
}

class ClaimCancelled implements Exception {
  const ClaimCancelled();
  @override
  String toString() => 'Claim cancelled by user';
}

/// Immutable context for one claim/send operation: the cancellation token and
/// RPC target belong to the operation, not to the service. A flow only ever
/// consults its own context, so starting a new operation on the same service
/// can neither un-cancel nor resurrect an older flow.
class WormholeOperation {
  /// Explicit RPC node URL; null uses the redundant remote endpoints.
  final String? rpcUrl;

  final Completer<void> _cancelRequested = Completer<void>();
  final Completer<void> _done = Completer<void>();

  WormholeOperation._(this.rpcUrl);

  bool get isCancelled => _cancelRequested.isCompleted;

  void _requestCancel() {
    if (!_cancelRequested.isCompleted) _cancelRequested.complete();
  }

  void checkCancelled() {
    if (isCancelled) throw const ClaimCancelled();
  }
}

/// One leaf proof to generate: consumes [transfer] (owned by [secret]) and
/// exits [outputAmount1] to [exitAccount1] plus optionally [outputAmount2] to
/// [exitAccount2] (change). Amounts are in scaled-down units.
class WormholeLeafSpend {
  final WormholeTransfer transfer;
  final Uint8List secret;
  final Uint8List exitAccount1;
  final int outputAmount1;
  final Uint8List? exitAccount2;
  final int outputAmount2;

  const WormholeLeafSpend({
    required this.transfer,
    required this.secret,
    required this.exitAccount1,
    required this.outputAmount1,
    this.exitAccount2,
    this.outputAmount2 = 0,
  });
}

/// Spends wormhole transfers by generating one ZK leaf proof per transfer,
/// aggregating them into 7-proof batches (the chain's aggregation arity; short
/// batches are padded with `dummy_proof.bin` inside the aggregator) and
/// submitting each aggregate as an unsigned extrinsic.
///
/// [claimRewards] is the mining-rewards flow: it discovers unspent transfers
/// for one address and pays everything to a single destination. [sendSpends]
/// takes explicit per-leaf output assignments (recipient + change) prepared by
/// coin selection, for encrypted-account sends.
///
/// Shared between the miner app (talks to a local node via [rpcUrl]) and the
/// mobile wallet (omits [rpcUrl] and uses the redundant remote endpoints).
class WormholeSendService {
  static const _stepTitles = {
    1: 'Preparing circuits',
    2: 'Gathering funds',
    3: 'Securing transaction',
    4: 'Generating ZK proofs',
    5: 'Aggregating proofs',
    6: 'Submitting to chain',
  };

  final WormholeUtxoService _utxoService = WormholeUtxoService();
  final RpcEndpointService _rpcEndpoint = RpcEndpointService();

  int _requestId = 1;

  /// The operation currently running on this service — only so [cancel] can
  /// find it. Flows never read this field; they use their own context.
  WormholeOperation? _currentOp;

  /// Signals cancellation of the in-flight operation and waits for that same
  /// operation to actually stop (success, partial result, error, or clean
  /// cancel). Because the token is captured here, a new operation started
  /// while we wait is unaffected and does not detach the old flow from its
  /// cancellation.
  Future<void> cancel() async {
    final op = _currentOp;
    if (op == null) return;
    op._requestCancel();
    await op._done.future;
  }

  Future<ClaimResult> claimRewards({
    required String wormholeAddress,
    required String secretHex,
    required String destinationAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    String? rpcUrl,
  }) {
    return _runOperation(
      rpcUrl,
      (op) => _runClaimFlow(
        op: op,
        wormholeAddress: wormholeAddress,
        secretHex: secretHex,
        destinationAddress: destinationAddress,
        circuitBinsDir: circuitBinsDir,
        onProgress: onProgress,
      ),
    );
  }

  /// Proves and submits pre-assigned spends. [batches] must respect the
  /// circuits' aggregation arity (checked against the circuit config).
  /// [onBatchSubmitted] is awaited after each batch's extrinsic is accepted,
  /// with the spent nullifier hexes — callers persist these to keep local
  /// pending-spend state exact even if a later batch fails.
  Future<ClaimResult> sendSpends({
    required List<List<WormholeLeafSpend>> batches,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    Future<void> Function(int batchIndex, List<String> nullifierHexes)? onBatchSubmitted,
    String? rpcUrl,
  }) {
    return _runOperation(rpcUrl, (op) async {
      final maxProofsPerBatch = await _ensureCircuits(op, circuitBinsDir, onProgress);
      for (final batch in batches) {
        if (batch.isEmpty || batch.length > maxProofsPerBatch) {
          throw StateError('Batch of ${batch.length} spends violates aggregation arity $maxProofsPerBatch');
        }
      }
      return _proveAndSubmitBatches(
        op: op,
        batches: batches,
        circuitBinsDir: circuitBinsDir,
        onProgress: onProgress,
        onBatchSubmitted: onBatchSubmitted,
      );
    });
  }

  /// Runs [flow] with its own [WormholeOperation] context. The caller always
  /// receives the flow's true outcome: cancellation is observed by the flow
  /// itself at its checkpoints (never by racing the flow against the cancel
  /// signal), so "cancelled" can never be reported while proving or submission
  /// is still running — and a cancel that lands after batches were submitted
  /// surfaces as a partial [ClaimResult], not as [ClaimCancelled].
  @visibleForTesting
  Future<ClaimResult> runOperation(String? rpcUrl, Future<ClaimResult> Function(WormholeOperation op) flow) =>
      _runOperation(rpcUrl, flow);

  Future<ClaimResult> _runOperation(String? rpcUrl, Future<ClaimResult> Function(WormholeOperation op) flow) async {
    final op = WormholeOperation._(rpcUrl);
    _currentOp = op;
    try {
      return await flow(op);
    } on WormholeOperationCancelled {
      throw const ClaimCancelled();
    } finally {
      if (identical(_currentOp, op)) _currentOp = null;
      op._done.complete();
    }
  }

  void _reportProgress(ClaimProgressCallback onProgress, int step, int completed, {int? total}) {
    _log('Step $step: ${_stepTitles[step]} $completed${total != null ? '/$total' : ''}');
    onProgress(ClaimProgressItem(step: step, title: _stepTitles[step]!, completed: completed, total: total));
  }

  /// Step 1: ensures circuit binaries exist and returns the aggregation arity.
  Future<int> _ensureCircuits(WormholeOperation op, String circuitBinsDir, ClaimProgressCallback onProgress) async {
    op.checkCancelled();
    _reportProgress(onProgress, 1, 0);
    _log('Ensuring circuit binaries at: $circuitBinsDir');
    final circuitConfig =
        jsonDecode(await wormhole_ffi.ensureCircuitBinaries(binsDir: circuitBinsDir)) as Map<String, dynamic>;
    // Batch size must match the circuits' aggregation arity (chain expects 7).
    final maxProofsPerBatch = circuitConfig['num_leaf_proofs'] as int;
    _log('Circuit binaries ready (num_leaf_proofs=$maxProofsPerBatch)');
    _reportProgress(onProgress, 1, 1);
    op.checkCancelled();
    return maxProofsPerBatch;
  }

  Future<ClaimResult> _runClaimFlow({
    required WormholeOperation op,
    required String wormholeAddress,
    required String secretHex,
    required String destinationAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
  }) async {
    final maxProofsPerBatch = await _ensureCircuits(op, circuitBinsDir, onProgress);

    _reportProgress(onProgress, 2, 0);
    final unspent = await _utxoService.getUnspentTransfers(
      wormholeAddress: wormholeAddress,
      secretHex: secretHex,
      isCancelled: () => op.isCancelled,
      onProgress: (phase, completed, {int? total}) {
        final step = phase <= 1 ? 2 : 3;
        _reportProgress(onProgress, step, completed, total: total);
      },
    );

    if (unspent.isEmpty) {
      return ClaimResult(totalWithdrawn: BigInt.zero, transfersProcessed: 0, batchesSubmitted: 0, txHashes: const []);
    }
    unspent.sort((a, b) => b.amount.compareTo(a.amount));
    _log('Found ${unspent.length} unspent transfers');
    op.checkCancelled();

    // A claim pays each leaf's full net (post-fee) amount to the destination.
    // The secret lives only in this buffer and is zeroized as soon as the
    // proofs are done (M11).
    final secretBytes = Uint8List.fromList(hex.decode(secretHex.replaceFirst('0x', '')));
    final destinationBytes = Uint8List.fromList(getAccountId32(destinationAddress));
    final spends = [
      for (final transfer in unspent)
        WormholeLeafSpend(
          transfer: transfer,
          secret: secretBytes,
          exitAccount1: destinationBytes,
          outputAmount1: wormholeNetScaled(wormholeScaledFromPlanck(transfer.amount)),
        ),
    ];
    final batches = [
      for (var i = 0; i < spends.length; i += maxProofsPerBatch)
        spends.sublist(i, (i + maxProofsPerBatch).clamp(0, spends.length)),
    ];

    try {
      return await _proveAndSubmitBatches(
        op: op,
        batches: batches,
        circuitBinsDir: circuitBinsDir,
        onProgress: onProgress,
      );
    } finally {
      secretBytes.fillRange(0, secretBytes.length, 0);
    }
  }

  Future<ClaimResult> _proveAndSubmitBatches({
    required WormholeOperation op,
    required List<List<WormholeLeafSpend>> batches,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    Future<void> Function(int batchIndex, List<String> nullifierHexes)? onBatchSubmitted,
  }) async {
    final numTransfers = batches.fold<int>(0, (sum, b) => sum + b.length);
    final totalBatches = batches.length;
    _reportProgress(onProgress, 4, 0, total: numTransfers);

    final txHashes = <String>[];
    BigInt recipientTotal = BigInt.zero;
    int proofsCompleted = 0;
    final genSw = Stopwatch()..start();

    try {
      for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
        op.checkCancelled();
        final batch = batches[batchIndex];
        final batchNum = batchIndex + 1;

        final blockHash = await _getBestBlockHash(op);
        final header = await _getBlockHeader(op, blockHash);
        final blockNumber = _hexToInt(header['number'] as String);
        final parentHash = _hexBytes(header['parentHash'] as String);
        final stateRoot = _hexBytes(header['stateRoot'] as String);
        final extrinsicsRoot = _hexBytes(header['extrinsicsRoot'] as String);
        final digest = _encodeDigest(header['digest'] as Map<String, dynamic>);
        final blockHashBytes = Uint8List.fromList(_hexBytes(blockHash));
        _log('Batch $batchNum/$totalBatches proof block: #$blockNumber ($blockHash)');

        final proofBytesList = List<Uint8List?>.filled(batch.length, null);
        final nullifierHexes = List<String?>.filled(batch.length, null);
        final futures = <Future<BigInt>>[];
        for (int i = 0; i < batch.length; i++) {
          final spend = batch[i];
          futures.add(
            _generateLeafProof(
              op: op,
              spend: spend,
              blockHash: blockHash,
              blockNumber: blockNumber,
              parentHash: parentHash,
              stateRoot: stateRoot,
              extrinsicsRoot: extrinsicsRoot,
              digest: digest,
              blockHashBytes: blockHashBytes,
              circuitBinsDir: circuitBinsDir,
              proofBuffer: proofBytesList,
              nullifierBuffer: nullifierHexes,
              outputIndex: i,
              onComplete: () {
                proofsCompleted++;
                // ignore: avoid_print
                print(
                  '[WormholeSend] Proof $proofsCompleted/$numTransfers '
                  'leaf=${spend.transfer.leafIndex} (${genSw.elapsedMilliseconds}ms elapsed)',
                );
                _reportProgress(onProgress, 4, proofsCompleted, total: numTransfers);
              },
            ),
          );
        }

        final outputs = await Future.wait(futures, eagerError: true);
        for (final out in outputs) {
          recipientTotal += out;
        }
        op.checkCancelled();

        _reportProgress(onProgress, 5, batchNum - 1, total: totalBatches);
        _log('Aggregating batch $batchNum/$totalBatches');
        final aggregated = await wormhole_ffi.aggregateProofs(
          proofBytesList: proofBytesList.cast<Uint8List>(),
          binsDir: circuitBinsDir,
        );
        _log('Batch $batchNum aggregated (${aggregated.length} bytes)');
        _reportProgress(onProgress, 5, batchNum, total: totalBatches);

        _reportProgress(onProgress, 6, batchNum - 1, total: totalBatches);
        // Last checkpoint before the point of no return: once the extrinsic
        // is handed to the node it cannot be aborted, so a cancel arriving
        // during submission is only honored before the *next* batch.
        op.checkCancelled();
        final txHash = await _submitExtrinsic(op, aggregated);
        txHashes.add(txHash);
        _log('Batch $batchNum accepted by pool: $txHash');
        await onBatchSubmitted?.call(batchIndex, nullifierHexes.cast<String>());
        _reportProgress(onProgress, 6, batchNum, total: totalBatches);
      }
    } on ClaimCancelled {
      // A cancel that lands after one or more batches were already submitted
      // is not a clean cancellation — those batches have paid out. Return the
      // partial result so callers report what actually happened instead of
      // "cancelled".
      if (txHashes.isEmpty) rethrow;
      final submitted = batches.take(txHashes.length);
      _log('Cancelled after ${txHashes.length}/$totalBatches batches were submitted');
      return ClaimResult(
        totalWithdrawn: submitted.fold(
          BigInt.zero,
          (sum, b) => sum + b.fold(BigInt.zero, (s, spend) => s + wormholePlanckFromScaled(spend.outputAmount1)),
        ),
        transfersProcessed: submitted.fold(0, (sum, b) => sum + b.length),
        batchesSubmitted: txHashes.length,
        txHashes: txHashes,
        cancelled: true,
      );
    } catch (e) {
      // Batches submitted before the failure have already paid out; surface
      // that instead of presenting the operation as a total failure. The
      // nullifier check skips paid transfers on retry.
      if (txHashes.isEmpty) rethrow;
      throw StateError(
        '${txHashes.length}/$totalBatches batches were submitted and paid out before this '
        'failure; retry to send the remaining transfers. Cause: $e',
      );
    }

    return ClaimResult(
      totalWithdrawn: recipientTotal,
      transfersProcessed: numTransfers,
      batchesSubmitted: txHashes.length,
      txHashes: txHashes,
    );
  }

  /// Generates a single leaf proof and writes it (and its nullifier hex) to
  /// the output buffers. Returns the planck amount paid to exit slot 1.
  /// [onComplete] fires once the proof is written so callers can update
  /// progress per-leaf.
  Future<BigInt> _generateLeafProof({
    required WormholeOperation op,
    required WormholeLeafSpend spend,
    required String blockHash,
    required int blockNumber,
    required List<int> parentHash,
    required List<int> stateRoot,
    required List<int> extrinsicsRoot,
    required List<int> digest,
    required Uint8List blockHashBytes,
    required String circuitBinsDir,
    required List<Uint8List?> proofBuffer,
    required List<String?> nullifierBuffer,
    required int outputIndex,
    void Function()? onComplete,
  }) async {
    op.checkCancelled();
    final transfer = spend.transfer;
    final zkProof = await _getZkMerkleProof(op, transfer.leafIndex, blockHash);

    final leafData = _toBytes(zkProof['leaf_data']);
    final leafHash = _toBytes(zkProof['leaf_hash']);
    final zkRoot = _toBytes(zkProof['root']);
    final depth = zkProof['depth'] as int;
    final rawSiblings = zkProof['siblings'] as List<dynamic>;

    final siblingsFlat = _flattenSiblings(rawSiblings);
    final merkle = wormhole_ffi.computeMerklePositions(
      unsortedSiblingsFlat: siblingsFlat,
      leafHash: leafHash,
      depth: depth,
    );

    final inputAmount = wormhole_ffi.decodeLeafAmount(leafData: leafData);
    final maxOutput = wormholeNetScaled(inputAmount);
    if (spend.outputAmount1 + spend.outputAmount2 > maxOutput) {
      throw StateError(
        'Leaf ${transfer.leafIndex}: assigned outputs ${spend.outputAmount1}+${spend.outputAmount2} '
        'exceed net input $maxOutput (input $inputAmount)',
      );
    }
    final wormholeAddressBytes = wormhole_ffi.decodeLeafToAccount(leafData: leafData);

    // The FFI proof itself cannot be interrupted, so check one last time
    // before starting the expensive part.
    op.checkCancelled();
    final proof = await wormhole_ffi.generateProof(
      input: wormhole_ffi.ProofInput(
        secret: spend.secret,
        transferCount: transfer.transferCount,
        wormholeAddress: wormholeAddressBytes,
        inputAmount: inputAmount,
        blockHash: blockHashBytes,
        blockNumber: blockNumber,
        parentHash: Uint8List.fromList(parentHash),
        stateRoot: Uint8List.fromList(stateRoot),
        extrinsicsRoot: Uint8List.fromList(extrinsicsRoot),
        digest: Uint8List.fromList(digest),
        zkTreeRoot: zkRoot,
        sortedSiblingsFlat: merkle.sortedSiblingsFlat,
        positions: merkle.positions,
        exitAccount1: spend.exitAccount1,
        outputAmount1: spend.outputAmount1,
        exitAccount2: spend.exitAccount2 ?? Uint8List(32),
        outputAmount2: spend.outputAmount2,
        volumeFeeBps: wormholeVolumeFeeBps,
        assetId: 0,
      ),
      proverBinPath: '$circuitBinsDir/prover.bin',
      commonBinPath: '$circuitBinsDir/common.bin',
    );
    proofBuffer[outputIndex] = proof.proofBytes;
    nullifierBuffer[outputIndex] = '0x${hex.encode(proof.nullifier)}';
    onComplete?.call();
    // On-chain dispatch transfers `outputAmount * scaleFactor` planck to
    // each exit account; slot 1 is the recipient's exact contribution.
    return wormholePlanckFromScaled(spend.outputAmount1);
  }

  /// Submits an unsigned extrinsic via `author_submitExtrinsic` and returns the
  /// pool-accepted tx hash. We don't wait for inclusion: pool acceptance of a
  /// well-formed unsigned extrinsic is a strong signal it will land, and any
  /// rejection (validation, insufficient priority, etc.) surfaces here as a
  /// JSON-RPC error from [_rpcCall].
  Future<String> _submitExtrinsic(WormholeOperation op, Uint8List aggregatedProofBytes) async {
    final fullExtrinsic = _wrapUnsignedExtrinsic(aggregatedProofBytes);
    final hexExtrinsic = '0x${hex.encode(fullExtrinsic)}';
    _log('Submitting unsigned extrinsic (${fullExtrinsic.length} bytes)');

    final result = await _rpcCall(op, 'author_submitExtrinsic', [hexExtrinsic]);
    if (result is! String) {
      throw StateError('author_submitExtrinsic returned ${result.runtimeType}: $result');
    }
    return result;
  }

  Uint8List _wrapUnsignedExtrinsic(Uint8List callBytes) {
    final runtimeCall = const wormhole_pallet.Txs().verifyPrivateBatch(proofBytes: callBytes);
    final callEncoded = runtimeCall.encode();

    // Unsigned extrinsic body: [version_byte=0x04][call_data]
    const versionByte = 0x04;
    final body = Uint8List(1 + callEncoded.length);
    body[0] = versionByte;
    body.setRange(1, body.length, callEncoded);

    final lengthPrefix = _compactEncode(body.length);
    final full = Uint8List(lengthPrefix.length + body.length);
    full.setAll(0, lengthPrefix);
    full.setAll(lengthPrefix.length, body);
    return full;
  }

  // --- RPC ---

  Future<String> _getBestBlockHash(WormholeOperation op) async {
    final result = await _rpcCall(op, 'chain_getBlockHash');
    if (result is! String) {
      throw StateError('chain_getBlockHash returned ${result.runtimeType}: $result');
    }
    return result;
  }

  Future<Map<String, dynamic>> _getBlockHeader(WormholeOperation op, String blockHash) async {
    final result = await _rpcCall(op, 'chain_getHeader', [blockHash]);
    if (result is! Map<String, dynamic>) {
      throw StateError('chain_getHeader returned ${result.runtimeType}: $result');
    }
    return result;
  }

  Future<Map<String, dynamic>> _getZkMerkleProof(WormholeOperation op, BigInt leafIndex, String blockHash) async {
    final result = await _rpcCall(op, 'zkTree_getMerkleProof', [leafIndex.toInt(), blockHash]);
    if (result is! Map<String, dynamic>) {
      throw StateError('zkTree_getMerkleProof for leaf $leafIndex returned ${result.runtimeType}: $result');
    }
    return result;
  }

  Future<dynamic> _rpcCall(WormholeOperation op, String method, [List<dynamic>? params]) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'id': _requestId++, 'method': method, 'params': params ?? []});

    final http.Response response;
    final url = op.rpcUrl;
    if (url != null) {
      response = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body);
    } else {
      response = await _rpcEndpoint.post(body: body);
    }

    if (response.statusCode != 200) {
      throw StateError('$method HTTP ${response.statusCode}: ${response.body}');
    }
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['error'] != null) {
      throw StateError('$method RPC error: ${parsed['error']}');
    }
    return parsed['result'];
  }

  // --- Utilities ---

  // ignore: avoid_print
  static void _log(String msg) => print('[WormholeSend] $msg');

  static int _hexToInt(String hexStr) => int.parse(hexStr.replaceFirst('0x', ''), radix: 16);

  static List<int> _hexBytes(String hexStr) => hex.decode(hexStr.replaceFirst('0x', ''));

  static Uint8List _toBytes(dynamic value) {
    if (value is String) return Uint8List.fromList(_hexBytes(value));
    if (value is List) return Uint8List.fromList(value.cast<int>());
    throw ArgumentError('Expected hex string or byte array, got ${value.runtimeType}');
  }

  static Uint8List _flattenSiblings(List<dynamic> rawSiblings) {
    final result = <int>[];
    for (final level in rawSiblings) {
      final siblings = level as List<dynamic>;
      for (final sibling in siblings) {
        if (sibling is String) {
          result.addAll(_hexBytes(sibling));
        } else if (sibling is List) {
          for (final b in sibling) {
            result.add(b as int);
          }
        }
      }
    }
    return Uint8List.fromList(result);
  }

  static List<int> _encodeDigest(Map<String, dynamic> digest) {
    final logs = digest['logs'] as List<dynamic>? ?? [];
    final output = ByteOutput(256);
    CompactCodec.codec.encodeTo(logs.length, output);
    for (final logEntry in logs) {
      final logHex = logEntry as String;
      output.write(_hexBytes(logHex));
    }
    return output.toBytes();
  }

  static Uint8List _compactEncode(int value) {
    final output = ByteOutput(5);
    CompactCodec.codec.encodeTo(value, output);
    return output.toBytes();
  }
}
