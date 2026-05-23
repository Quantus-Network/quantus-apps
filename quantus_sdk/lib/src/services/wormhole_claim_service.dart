import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/generated/planck/pallets/wormhole.dart' as wormhole_pallet;
import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole_ffi;
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart' show getAccountId32;
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:polkadart/scale_codec.dart' show ByteOutput, CompactCodec;

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
  static const int _maxProofsPerBatch = 16;
  static const int _proofConcurrency = 16;
  static const int _volumeFeeBps = 10;
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
  final RpcEndpointService _rpcEndpoint = RpcEndpointService();
  final String? _rpcUrl;

  Completer<void>? _cancelCompleter;

  WormholeClaimService({String? rpcUrl}) : _rpcUrl = rpcUrl;

  bool get _cancelled => _cancelCompleter?.isCompleted ?? false;

  void cancel() {
    final c = _cancelCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<ClaimResult> claimRewards({
    required String wormholeAddress,
    required String secretHex,
    required String destinationAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
  }) async {
    final cancelCompleter = Completer<void>();
    _cancelCompleter = cancelCompleter;

    try {
      final flow = _runClaimFlow(
        wormholeAddress: wormholeAddress,
        secretHex: secretHex,
        destinationAddress: destinationAddress,
        circuitBinsDir: circuitBinsDir,
        onProgress: onProgress,
      );
      final cancelGuard = cancelCompleter.future.then<ClaimResult>((_) => throw const ClaimCancelled());
      return await Future.any([flow, cancelGuard]);
    } on WormholeOperationCancelled {
      throw const ClaimCancelled();
    }
  }

  void _reportProgress(ClaimProgressCallback onProgress, int step, int completed, {int? total}) {
    _log('Step $step: ${_stepTitles[step]} $completed${total != null ? '/$total' : ''}');
    onProgress(ClaimProgressItem(step: step, title: _stepTitles[step]!, completed: completed, total: total));
  }

  void _checkCancelled() {
    if (_cancelled) throw const ClaimCancelled();
  }

  Future<ClaimResult> _runClaimFlow({
    required String wormholeAddress,
    required String secretHex,
    required String destinationAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
  }) async {
    _checkCancelled();

    _reportProgress(onProgress, 1, 0);
    _log('Ensuring circuit binaries at: $circuitBinsDir');
    await wormhole_ffi.ensureCircuitBinaries(binsDir: circuitBinsDir);
    _log('Circuit binaries ready');
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
    _log('Found ${unspent.length} unspent transfers');
    _checkCancelled();

    _reportProgress(onProgress, 5, 0, total: unspent.length);

    final String blockHash = await _rpcCall('chain_getBlockHash') as String;
    final header = await _rpcCall('chain_getHeader', [blockHash]);
    final blockNumber = _hexToInt(header['number'] as String);
    final parentHash = _hexBytes(header['parentHash'] as String);
    final stateRoot = _hexBytes(header['stateRoot'] as String);
    final extrinsicsRoot = _hexBytes(header['extrinsicsRoot'] as String);
    final digest = _encodeDigest(header['digest'] as Map<String, dynamic>);
    _log('Proof block: #$blockNumber ($blockHash)');
    _checkCancelled();

    final numTransfers = unspent.length;
    final proofBytesList = List<Uint8List?>.filled(numTransfers, null);
    final secretBytes = Uint8List.fromList(hex.decode(secretHex.replaceFirst('0x', '')));
    final destinationBytes = Uint8List.fromList(getAccountId32(destinationAddress));
    final blockHashBytes = Uint8List.fromList(_hexBytes(blockHash));

    BigInt netTotal = BigInt.zero;
    int completed = 0;
    final genSw = Stopwatch()..start();

    for (int chunk = 0; chunk < numTransfers; chunk += _proofConcurrency) {
      _checkCancelled();
      final end = (chunk + _proofConcurrency).clamp(0, numTransfers);
      final futures = <Future<BigInt>>[];

      for (int i = chunk; i < end; i++) {
        final transfer = unspent[i];
        futures.add(
          _generateLeafProof(
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
            outputIndex: i,
            onComplete: () {
              completed++;
              print(
                '[WormholeClaim] Proof $completed/$numTransfers '
                'leaf=${transfer.leafIndex} (${genSw.elapsedMilliseconds}ms elapsed)',
              );
              _reportProgress(onProgress, 5, completed, total: numTransfers);
            },
          ),
        );
      }

      final outputs = await Future.wait(futures, eagerError: true);
      for (final out in outputs) {
        netTotal += out;
      }
      _checkCancelled();
    }

    final finalProofs = proofBytesList.cast<Uint8List>();
    final batches = <List<Uint8List>>[];
    for (int i = 0; i < finalProofs.length; i += _maxProofsPerBatch) {
      final end = (i + _maxProofsPerBatch).clamp(0, finalProofs.length);
      batches.add(finalProofs.sublist(i, end));
    }

    final txHashes = <String>[];
    _reportProgress(onProgress, 6, 0, total: batches.length);
    for (int b = 0; b < batches.length; b++) {
      _checkCancelled();
      _log('Aggregating batch ${b + 1}/${batches.length}');
      final aggregated = await wormhole_ffi.aggregateProofs(proofBytesList: batches[b], binsDir: circuitBinsDir);
      _log('Batch ${b + 1} aggregated (${aggregated.length} bytes)');
      _checkCancelled();

      final txHash = await _submitExtrinsic(aggregated);
      txHashes.add(txHash);
      _log('Batch ${b + 1} accepted by pool: $txHash');
      _reportProgress(onProgress, 6, b + 1, total: batches.length);
    }

    return ClaimResult(
      totalWithdrawn: netTotal,
      transfersProcessed: numTransfers,
      batchesSubmitted: batches.length,
      txHashes: txHashes,
    );
  }

  Future<BigInt> _generateLeafProof({
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
    final zkProof = await _rpcCall('zkTree_getMerkleProof', [transfer.leafIndex.toInt(), blockHash]);

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
    final outputAmount = wormhole_ffi.wormholeComputeOutputAmount(inputAmount: inputAmount, feeBps: _volumeFeeBps);
    final wormholeAddressBytes = wormhole_ffi.decodeLeafToAccount(leafData: leafData);

    final proof = await wormhole_ffi.generateProof(
      input: wormhole_ffi.ProofInput(
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
    return BigInt.from(outputAmount) * _scaleDownFactor;
  }

  Future<String> _submitExtrinsic(Uint8List aggregatedProofBytes) async {
    final fullExtrinsic = _wrapUnsignedExtrinsic(aggregatedProofBytes);
    final hexExtrinsic = '0x${hex.encode(fullExtrinsic)}';
    _log('Submitting unsigned extrinsic (${fullExtrinsic.length} bytes)');

    final result = await _rpcCall('author_submitExtrinsic', [hexExtrinsic]);
    if (result is! String) {
      throw StateError('author_submitExtrinsic returned ${result.runtimeType}: $result');
    }
    return result;
  }

  Uint8List _wrapUnsignedExtrinsic(Uint8List callBytes) {
    final runtimeCall = const wormhole_pallet.Txs().verifyAggregatedProof(proofBytes: callBytes);
    final callEncoded = runtimeCall.encode();

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

  // --- RPC helpers ---

  Future<dynamic> _rpcCall(String method, [List<dynamic>? params]) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params ?? []});

    final http.Response response;
    if (_rpcUrl != null) {
      response = await http.post(Uri.parse(_rpcUrl), headers: {'Content-Type': 'application/json'}, body: body);
    } else {
      response = await _rpcEndpoint.post(body: body);
    }

    if (response.statusCode != 200) {
      throw Exception('$method HTTP ${response.statusCode}: ${response.body}');
    }
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['error'] != null) {
      throw Exception('$method RPC error: ${parsed['error']}');
    }
    return parsed['result'];
  }

  // --- Utilities ---

  static void _log(String msg) => print('[WormholeClaim] $msg');

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
