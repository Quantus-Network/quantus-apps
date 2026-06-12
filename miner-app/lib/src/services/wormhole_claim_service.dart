import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:quantus_miner/src/services/chain_rpc_client.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/generated/planck/pallets/wormhole.dart' as wormhole_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';

final _log = log.withTag('WormholeClaim');

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

  const ClaimResult({
    required this.totalWithdrawn,
    required this.transfersProcessed,
    required this.batchesSubmitted,
    required this.txHashes,
  });
}

class ClaimCancelled implements Exception {
  const ClaimCancelled();
  @override
  String toString() => 'Claim cancelled by user';
}

class WormholeClaimService {
  static const int _volumeFeeBps = 10;

  /// Scaled-down → planck multiplier; matches `SCALE_DOWN_FACTOR` in the Rust
  /// wormhole API. The proof commits to amounts in scaled-down units, and the
  /// chain dispatches `outputAmount * scaleDownFactor` planck.
  static final BigInt _scaleDownFactor = BigInt.from(10000000000);

  static const _stepTitles = {
    1: 'Preparing circuits',
    2: 'Fetching transfers',
    3: 'Computing nullifiers',
    4: 'Checking nullifiers',
    5: 'Generating ZK proofs',
    6: 'Submitting to chain',
  };

  final WormholeUtxoService _utxoService = WormholeUtxoService();

  /// Completes when the user cancels. Polled by [_checkCancelled] for cheap
  /// chain-level checks and raced against the whole flow in [claimRewards] so
  /// cancellation is instantaneous even mid-FFI (in-flight proofs are simply
  /// orphaned — they'll finish in the background and their results discarded).
  Completer<void>? _cancelCompleter;

  bool get _cancelled => _cancelCompleter?.isCompleted ?? false;

  void cancel() {
    final c = _cancelCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<ClaimResult> claimRewards({
    required String wormholeAddress,
    required String secretHex,
    required String destinationAddress,
    required String rpcUrl,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
  }) async {
    final cancelCompleter = Completer<void>();
    _cancelCompleter = cancelCompleter;

    final rpc = ChainRpcClient(rpcUrl: rpcUrl, timeout: const Duration(seconds: 30));
    try {
      final flow = _runClaimFlow(
        rpc: rpc,
        wormholeAddress: wormholeAddress,
        secretHex: secretHex,
        destinationAddress: destinationAddress,
        circuitBinsDir: circuitBinsDir,
        onProgress: onProgress,
      );
      // Race the flow against cancellation. Future.any returns the first to
      // complete; the loser's later completion (success or error) is silently
      // ignored by Future.any, so abandoned in-flight FFI work won't surface
      // as an unhandled async error.
      final cancelGuard = cancelCompleter.future.then<ClaimResult>((_) => throw const ClaimCancelled());
      return await Future.any([flow, cancelGuard]);
    } on WormholeOperationCancelled {
      throw const ClaimCancelled();
    } finally {
      rpc.dispose();
    }
  }

  void _reportProgress(ClaimProgressCallback onProgress, int step, int completed, {int? total}) {
    _log.i('Step $step: ${_stepTitles[step]} $completed${total != null ? '/$total' : ''}');
    onProgress(ClaimProgressItem(step: step, title: _stepTitles[step]!, completed: completed, total: total));
  }

  void _checkCancelled() {
    if (_cancelled) throw const ClaimCancelled();
  }

  Future<ClaimResult> _runClaimFlow({
    required ChainRpcClient rpc,
    required String wormholeAddress,
    required String secretHex,
    required String destinationAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
  }) async {
    _checkCancelled();

    _reportProgress(onProgress, 1, 0);
    _log.i('Ensuring circuit binaries at: $circuitBinsDir');
    final circuitConfig = jsonDecode(await ensureCircuitBinaries(binsDir: circuitBinsDir)) as Map<String, dynamic>;
    // Batch size must match the circuits' aggregation arity (chain expects 7).
    final maxProofsPerBatch = circuitConfig['num_leaf_proofs'] as int;
    _log.i('Circuit binaries ready (num_leaf_proofs=$maxProofsPerBatch)');
    _reportProgress(onProgress, 1, 1);
    _checkCancelled();

    _reportProgress(onProgress, 2, 0);
    final unspent = await _utxoService.getUnspentTransfers(
      wormholeAddress: wormholeAddress,
      secretHex: secretHex,
      isCancelled: () => _cancelled,
      onProgress: (phase, completed, {int? total}) {
        _reportProgress(onProgress, phase + 1, completed, total: total);
      },
    );

    if (unspent.isEmpty) {
      return ClaimResult(totalWithdrawn: BigInt.zero, transfersProcessed: 0, batchesSubmitted: 0, txHashes: const []);
    }
    unspent.sort((a, b) => b.amount.compareTo(a.amount));
    _log.i('Found ${unspent.length} unspent transfers');
    _checkCancelled();

    final numTransfers = unspent.length;
    final totalBatches = (numTransfers + maxProofsPerBatch - 1) ~/ maxProofsPerBatch;
    final secretBytes = Uint8List.fromList(hex.decode(secretHex.replaceFirst('0x', '')));
    final destinationBytes = Uint8List.fromList(getAccountId32(destinationAddress));

    _reportProgress(onProgress, 5, 0, total: numTransfers);

    final txHashes = <String>[];
    BigInt netTotal = BigInt.zero;
    int proofsCompleted = 0;
    final genSw = Stopwatch()..start();

    // Process one aggregation batch at a time: generate its leaf proofs, then
    // aggregate and submit before moving on. Each submitted batch pays out
    // immediately instead of waiting for the whole queue to be proven.
    try {
      for (int batchStart = 0; batchStart < numTransfers; batchStart += maxProofsPerBatch) {
        _checkCancelled();
        final batchEnd = (batchStart + maxProofsPerBatch).clamp(0, numTransfers);
        final batchNum = batchStart ~/ maxProofsPerBatch + 1;

        // Use the current head (not finalized) as the proof block: the user is
        // claiming up to the chain tip, and the merkle tree at the finalized head
        // would not contain transfers in the last `reorgDepth` blocks. Fetched
        // per batch so long claims don't reference an increasingly stale block.
        // A reorg before a batch lands will cause on-chain verification to fail
        // and the user can simply retry.
        final blockHash = await rpc.getBestBlockHash();
        final header = await rpc.getBlockHeader(blockHash: blockHash);
        final blockNumber = _hexToInt(header['number'] as String);
        final parentHash = _hexBytes(header['parentHash'] as String);
        final stateRoot = _hexBytes(header['stateRoot'] as String);
        final extrinsicsRoot = _hexBytes(header['extrinsicsRoot'] as String);
        final digest = _encodeDigest(header['digest'] as Map<String, dynamic>);
        final blockHashBytes = Uint8List.fromList(_hexBytes(blockHash));
        _log.i('Batch $batchNum/$totalBatches proof block: #$blockNumber ($blockHash)');

        final proofBytesList = List<Uint8List?>.filled(batchEnd - batchStart, null);
        final futures = <Future<BigInt>>[];
        for (int i = batchStart; i < batchEnd; i++) {
          final transfer = unspent[i];
          futures.add(
            _generateLeafProof(
              rpc: rpc,
              transfer: transfer,
              blockHash: blockHash,
              blockNumber: blockNumber,
              parentHash: parentHash,
              stateRoot: stateRoot,
              extrinsicsRoot: extrinsicsRoot,
              digest: digest,
              blockHashBytes: blockHashBytes,
              secretBytes: secretBytes,
              destinationBytes: destinationBytes,
              circuitBinsDir: circuitBinsDir,
              outputBuffer: proofBytesList,
              outputIndex: i - batchStart,
              onComplete: () {
                proofsCompleted++;
                // Plain stdout print (not debugPrint) so it survives in release
                // builds and is visible from the launching terminal.
                // ignore: avoid_print
                print(
                  '[WormholeClaim] Proof $proofsCompleted/$numTransfers '
                  'leaf=${transfer.leafIndex} (${genSw.elapsedMilliseconds}ms elapsed)',
                );
                _reportProgress(onProgress, 5, proofsCompleted, total: numTransfers);
              },
            ),
          );
        }

        final outputs = await Future.wait(futures, eagerError: true);
        for (final out in outputs) {
          netTotal += out;
        }
        _checkCancelled();

        _log.i('Aggregating batch $batchNum/$totalBatches');
        final aggregated = await aggregateProofs(
          proofBytesList: proofBytesList.cast<Uint8List>(),
          binsDir: circuitBinsDir,
        );
        _log.i('Batch $batchNum aggregated (${aggregated.length} bytes)');
        _checkCancelled();

        final txHash = await _submitExtrinsic(rpc, aggregated);
        txHashes.add(txHash);
        _log.i('Batch $batchNum accepted by pool: $txHash');
        _reportProgress(onProgress, 6, batchNum, total: totalBatches);
      }
    } on ClaimCancelled {
      rethrow;
    } catch (e) {
      // Batches submitted before the failure have already paid out; surface
      // that instead of presenting the claim as a total failure. The nullifier
      // check skips paid transfers on retry.
      if (txHashes.isEmpty) rethrow;
      throw StateError(
        '${txHashes.length}/$totalBatches batches were submitted and paid out before this '
        'failure; retry to claim the remaining transfers. Cause: $e',
      );
    }

    return ClaimResult(
      totalWithdrawn: netTotal,
      transfersProcessed: numTransfers,
      batchesSubmitted: txHashes.length,
      txHashes: txHashes,
    );
  }

  /// Generates a single leaf proof and writes it to [outputBuffer]. Returns the
  /// net (post-fee) output amount this leaf contributes. [onComplete] fires
  /// once the proof is written so callers can update progress per-leaf.
  Future<BigInt> _generateLeafProof({
    required ChainRpcClient rpc,
    required WormholeTransfer transfer,
    required String blockHash,
    required int blockNumber,
    required List<int> parentHash,
    required List<int> stateRoot,
    required List<int> extrinsicsRoot,
    required List<int> digest,
    required Uint8List blockHashBytes,
    required Uint8List secretBytes,
    required Uint8List destinationBytes,
    required String circuitBinsDir,
    required List<Uint8List?> outputBuffer,
    required int outputIndex,
    void Function()? onComplete,
  }) async {
    final zkProof = await rpc.getZkMerkleProof(transfer.leafIndex, blockHash);

    final leafData = _toBytes(zkProof['leaf_data']);
    final leafHash = _toBytes(zkProof['leaf_hash']);
    final zkRoot = _toBytes(zkProof['root']);
    final depth = zkProof['depth'] as int;
    final rawSiblings = zkProof['siblings'] as List<dynamic>;

    final siblingsFlat = _flattenSiblings(rawSiblings);
    final merkle = computeMerklePositions(unsortedSiblingsFlat: siblingsFlat, leafHash: leafHash, depth: depth);

    final inputAmount = decodeLeafAmount(leafData: leafData);
    final outputAmount = wormholeComputeOutputAmount(inputAmount: inputAmount, feeBps: _volumeFeeBps);
    final wormholeAddressBytes = decodeLeafToAccount(leafData: leafData);

    final proof = await generateProof(
      input: ProofInput(
        secret: secretBytes,
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
        exitAccount1: destinationBytes,
        outputAmount1: outputAmount,
        volumeFeeBps: _volumeFeeBps,
        assetId: 0,
      ),
      proverBinPath: '$circuitBinsDir/prover.bin',
      commonBinPath: '$circuitBinsDir/common.bin',
    );
    outputBuffer[outputIndex] = proof.proofBytes;
    onComplete?.call();
    // On-chain dispatch transfers `outputAmount * scaleDownFactor` planck to
    // the destination, so this is the exact net contribution per leaf.
    return BigInt.from(outputAmount) * _scaleDownFactor;
  }

  /// Submits an unsigned extrinsic via `author_submitExtrinsic` and returns the
  /// pool-accepted tx hash. We don't wait for inclusion: pool acceptance of a
  /// well-formed unsigned extrinsic is a strong signal it will land, and any
  /// rejection (validation, insufficient priority, etc.) surfaces here as a
  /// JSON-RPC error from [ChainRpcClient.rpcCall].
  Future<String> _submitExtrinsic(ChainRpcClient rpc, Uint8List aggregatedProofBytes) async {
    final fullExtrinsic = _wrapUnsignedExtrinsic(aggregatedProofBytes);
    final hexExtrinsic = '0x${hex.encode(fullExtrinsic)}';
    _log.i('Submitting unsigned extrinsic (${fullExtrinsic.length} bytes)');

    final result = await rpc.rpcCall('author_submitExtrinsic', [hexExtrinsic]);
    if (result is! String) {
      throw StateError('author_submitExtrinsic returned ${result.runtimeType}: $result');
    }
    return result;
  }

  Uint8List _wrapUnsignedExtrinsic(Uint8List callBytes) {
    final runtimeCall = const wormhole_pallet.Txs().verifyAggregatedProof(proofBytes: callBytes);
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
