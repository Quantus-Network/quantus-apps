import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:polkadart/scale_codec.dart' as scale;
import 'package:quantus_sdk/generated/planck/types/frame_system/event_record.dart';
import 'package:quantus_sdk/generated/planck/types/pallet_wormhole/pallet/call.dart' as wormhole_call;
import 'package:quantus_sdk/generated/planck/types/pallet_wormhole/pallet/event.dart' as wormhole_event;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_event.dart' as runtime_event;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/dispatch_error.dart' as dispatch_error;
import 'package:quantus_sdk/generated/planck/types/frame_system/pallet/event.dart' as system_event;
import 'package:quantus_sdk/generated/planck/types/frame_system/phase.dart' as system_phase;
import 'package:quantus_sdk/src/services/substrate_service.dart';
import 'package:quantus_sdk/src/services/wormhole_address_manager.dart';
import 'package:quantus_sdk/src/services/wormhole_service.dart';
import 'package:ss58/ss58.dart' as ss58;

/// Progress callback for withdrawal operations.
typedef WithdrawalProgressCallback = void Function(double progress, String message);

/// Result of a withdrawal operation.
class WithdrawalResult {
  final bool success;
  final String? txHash;
  final String? error;
  final BigInt? exitAmount;

  /// If change was generated, this is the address where it was sent.
  final String? changeAddress;

  /// The amount sent to the change address (in planck).
  final BigInt? changeAmount;

  const WithdrawalResult({
    required this.success,
    this.txHash,
    this.error,
    this.exitAmount,
    this.changeAddress,
    this.changeAmount,
  });
}

/// Information about a transfer needed for proof generation.
class WormholeTransferInfo {
  final String blockHash;
  final BigInt transferCount;
  final BigInt amount;
  final String wormholeAddress;
  final String fundingAccount;
  final String? fundingAccountHex;

  const WormholeTransferInfo({
    required this.blockHash,
    required this.transferCount,
    required this.amount,
    required this.wormholeAddress,
    required this.fundingAccount,
    this.fundingAccountHex,
  });

  @override
  String toString() => 'WormholeTransferInfo(blockHash: $blockHash, transferCount: $transferCount, amount: $amount)';
}

/// Service for handling wormhole withdrawals.
///
/// This orchestrates the entire withdrawal flow:
/// 1. Query chain for transfer count and transfer proofs
/// 2. For each transfer: fetch storage proof and generate ZK proof
/// 3. Aggregate proofs
/// 4. Submit transaction to chain
///
/// ## Usage
///
/// ```dart
/// final service = WormholeWithdrawalService();
///
/// final result = await service.withdraw(
///   rpcUrl: 'wss://rpc.quantus.network',
///   secretHex: '0x...',
///   wormholeAddress: 'qz...',
///   destinationAddress: 'qz...',
///   circuitBinsDir: '/path/to/circuits',
///   transfers: myTrackedTransfers,
///   onProgress: (progress, message) => print('$progress: $message'),
/// );
///
/// if (result.success) {
///   print('Withdrawal successful: ${result.txHash}');
/// }
/// ```
class WormholeWithdrawalService {
  WormholeWithdrawalService({this.enableDebugLogs = true});

  final bool enableDebugLogs;

  // Fee in basis points (10 = 0.1%)
  static const int feeBps = 10;

  // Minimum output after quantization (3 units = 0.03 QTN)
  static final BigInt minOutputPlanck = BigInt.from(3) * BigInt.from(10).pow(10);

  // Native asset ID (0 for native token)
  static const int nativeAssetId = 0;

  // Default batch size (number of proofs per aggregation)
  static const int defaultBatchSize = 16;

  /// Withdraw funds from a wormhole address.
  ///
  /// [rpcUrl] - The RPC endpoint URL
  /// [secretHex] - The wormhole secret for proof generation
  /// [wormholeAddress] - The source wormhole address (SS58)
  /// [destinationAddress] - Where to send the withdrawn funds (SS58)
  /// [amount] - Amount to withdraw in planck (null = withdraw all)
  /// [circuitBinsDir] - Directory containing circuit binary files
  /// [transfers] - Pre-tracked transfers with exact amounts
  /// [addressManager] - Optional address manager for deriving change addresses
  /// [onProgress] - Progress callback for UI updates
  Future<WithdrawalResult> withdraw({
    required String rpcUrl,
    required String secretHex,
    required String wormholeAddress,
    required String destinationAddress,
    BigInt? amount,
    required String circuitBinsDir,
    required List<WormholeTransferInfo> transfers,
    WormholeAddressManager? addressManager,
    WithdrawalProgressCallback? onProgress,
  }) async {
    try {
      _debug(
        'start withdraw rpc=$rpcUrl source=$wormholeAddress destination=$destinationAddress amount=${amount ?? 'ALL'} transfers=${transfers.length}',
      );
      onProgress?.call(0.05, 'Preparing withdrawal...');

      if (transfers.isEmpty) {
        return const WithdrawalResult(success: false, error: 'No transfers provided for withdrawal');
      }

      // Calculate total available
      final totalAvailable = transfers.fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amount);

      // Determine amount to withdraw
      final withdrawAmount = amount ?? totalAvailable;
      if (withdrawAmount > totalAvailable) {
        return WithdrawalResult(
          success: false,
          error: 'Insufficient balance. Available: $totalAvailable, requested: $withdrawAmount',
        );
      }

      onProgress?.call(0.1, 'Selecting transfers...');

      // Select transfers
      final selectedTransfers = _selectTransfers(transfers, withdrawAmount);
      final selectedTotal = selectedTransfers.fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amount);
      _debug(
        'selected transfers=${selectedTransfers.length} selectedTotal=$selectedTotal withdrawAmount=$withdrawAmount',
      );

      // Calculate output amounts after fee
      final totalAfterFee = selectedTotal - (selectedTotal * BigInt.from(feeBps) ~/ BigInt.from(10000));

      if (totalAfterFee < minOutputPlanck) {
        return const WithdrawalResult(success: false, error: 'Amount too small after fee (minimum ~0.03 QTN)');
      }

      onProgress?.call(0.15, 'Loading circuit data...');

      // Create proof generator
      final wormholeService = WormholeService();
      final generator = await wormholeService.createProofGenerator(circuitBinsDir);
      var batchAggregator = await wormholeService.createProofAggregator(circuitBinsDir);

      onProgress?.call(0.18, 'Fetching current block...');

      // Choose a common proof block for all selected transfers.
      // Prefer the earliest block that contains all selected transfers.
      final proofBlockHash = await _selectCommonProofBlockHash(rpcUrl: rpcUrl, selectedTransfers: selectedTransfers);
      _debug('proof block hash=$proofBlockHash');

      // Calculate if we need change
      final requestedAmountQuantized = wormholeService.quantizeAmount(withdrawAmount);

      // Calculate max possible outputs for each transfer
      final maxOutputsQuantized = selectedTransfers.map((t) {
        final inputQuantized = wormholeService.quantizeAmount(t.amount);
        return wormholeService.computeOutputAmount(inputQuantized, feeBps);
      }).toList();
      final totalMaxOutputQuantized = maxOutputsQuantized.fold<int>(0, (a, b) => a + b);

      // Determine if change is needed
      final needsChange = requestedAmountQuantized < totalMaxOutputQuantized;
      String? changeAddress;
      TrackedWormholeAddress? changeAddressInfo;

      if (needsChange) {
        if (addressManager == null) {
          return const WithdrawalResult(
            success: false,
            error: 'Partial withdrawal requires address manager for change address',
          );
        }

        onProgress?.call(0.19, 'Deriving change address...');
        changeAddressInfo = await addressManager.deriveNextChangeAddress();
        changeAddress = changeAddressInfo.address;
      }

      onProgress?.call(0.2, 'Generating proofs...');

      // Generate proofs for each transfer
      final proofs = <GeneratedProof>[];
      var remainingToSend = requestedAmountQuantized;

      for (int i = 0; i < selectedTransfers.length; i++) {
        final transfer = selectedTransfers[i];
        final maxOutput = maxOutputsQuantized[i];
        final isLastTransfer = i == selectedTransfers.length - 1;

        final progress = 0.2 + (0.5 * (i / selectedTransfers.length));
        onProgress?.call(progress, 'Generating proof ${i + 1}/${selectedTransfers.length}...');

        // Determine output and change amounts for this proof
        int outputAmount;
        int proofChangeAmount = 0;

        if (isLastTransfer && needsChange) {
          outputAmount = remainingToSend;
          proofChangeAmount = maxOutput - outputAmount;
          if (proofChangeAmount < 0) proofChangeAmount = 0;
        } else if (needsChange) {
          outputAmount = remainingToSend < maxOutput ? remainingToSend : maxOutput;
        } else {
          outputAmount = maxOutput;
        }

        remainingToSend -= outputAmount;

        try {
          final transferSecretHex = _resolveTransferSecret(
            transfer: transfer,
            primarySecretHex: secretHex,
            primaryWormholeAddress: wormholeAddress,
            addressManager: addressManager,
            wormholeService: wormholeService,
          );

          final proof = await _generateProofForTransfer(
            generator: generator,
            wormholeService: wormholeService,
            transfer: transfer,
            secretHex: transferSecretHex,
            destinationAddress: destinationAddress,
            rpcUrl: rpcUrl,
            proofBlockHash: proofBlockHash,
            outputAmount: needsChange ? outputAmount : null,
            changeAmount: proofChangeAmount,
            changeAddress: changeAddress,
          );
          proofs.add(proof);
        } catch (e) {
          _debug(
            'proof generation failed at index=$i transferCount=${transfer.transferCount} to=${transfer.wormholeAddress} from=${transfer.fundingAccount} amount=${transfer.amount} error=$e',
          );
          return WithdrawalResult(success: false, error: 'Failed to generate proof: $e');
        }
      }

      // Get the batch size from the aggregator
      final batchSize = await batchAggregator.batchSize;

      // Split proofs into batches if needed
      final numBatches = (proofs.length + batchSize - 1) ~/ batchSize;
      _debug('aggregating proofs=${proofs.length} batchSize=$batchSize batches=$numBatches');

      final txHashes = <String>[];

      for (int batchIdx = 0; batchIdx < numBatches; batchIdx++) {
        if (batchIdx > 0) {
          batchAggregator = await wormholeService.createProofAggregator(circuitBinsDir);
        }

        final batchStart = batchIdx * batchSize;
        final batchEnd = (batchStart + batchSize).clamp(0, proofs.length);
        final batchProofs = proofs.sublist(batchStart, batchEnd);

        final aggregateProgress = 0.7 + (0.1 * (batchIdx / numBatches));
        onProgress?.call(
          aggregateProgress,
          'Aggregating batch ${batchIdx + 1}/$numBatches (${batchProofs.length} proofs)...',
        );

        // IMPORTANT: SDK clear() is a no-op; use a fresh aggregator per batch.
        for (final proof in batchProofs) {
          await batchAggregator.addGeneratedProof(proof);
        }
        final aggregatedProof = await batchAggregator.aggregate();

        final submitProgress = 0.8 + (0.15 * (batchIdx / numBatches));
        onProgress?.call(submitProgress, 'Submitting batch ${batchIdx + 1}/$numBatches...');

        // Submit this batch
        final txHash = await _submitProof(proofHex: aggregatedProof.proofHex);
        txHashes.add(txHash);
        _debug('submitted batch ${batchIdx + 1}/$numBatches txHash=$txHash proofsInBatch=${batchProofs.length}');
      }

      onProgress?.call(0.95, 'Waiting for confirmations...');

      // Wait for transaction confirmation
      final lastTxHash = txHashes.last;
      final confirmed = await _waitForTransactionConfirmation(
        txHash: lastTxHash,
        rpcUrl: rpcUrl,
        destinationAddress: destinationAddress,
        expectedAmount: totalAfterFee,
      );

      if (!confirmed) {
        _debug('confirmation failed txHashes=${txHashes.join(', ')}');
        return WithdrawalResult(
          success: false,
          txHash: txHashes.join(', '),
          error: 'Transactions submitted but could not confirm success. Check txs: ${txHashes.join(', ')}',
        );
      }

      onProgress?.call(1.0, 'Withdrawal complete!');

      // Calculate change amount in planck if change was used
      BigInt? changeAmountPlanck;
      if (needsChange && changeAddress != null) {
        final changeQuantized = totalMaxOutputQuantized - requestedAmountQuantized;
        changeAmountPlanck = wormholeService.dequantizeAmount(changeQuantized);
      }

      return WithdrawalResult(
        success: true,
        txHash: txHashes.join(', '),
        exitAmount: totalAfterFee,
        changeAddress: changeAddress,
        changeAmount: changeAmountPlanck,
      );
    } catch (e) {
      _debug('withdraw exception: $e');
      return WithdrawalResult(success: false, error: e.toString());
    }
  }

  String _resolveTransferSecret({
    required WormholeTransferInfo transfer,
    required String primarySecretHex,
    required String primaryWormholeAddress,
    required WormholeAddressManager? addressManager,
    required WormholeService wormholeService,
  }) {
    final transferAddress = transfer.wormholeAddress;

    if (transferAddress == primaryWormholeAddress) {
      _debug('secret resolved via primary address for transfer=$transferAddress');
      return primarySecretHex;
    }

    final tracked = addressManager?.getAddress(transferAddress);
    if (tracked != null) {
      _debug(
        'secret resolved via addressManager for transfer=$transferAddress purpose=${tracked.purpose} index=${tracked.index}',
      );
      return tracked.secretHex;
    }

    final derivedPrimary = wormholeService.deriveAddressFromSecret(primarySecretHex);
    if (derivedPrimary == transferAddress) {
      _debug('secret resolved via derived primary match for transfer=$transferAddress');
      return primarySecretHex;
    }

    throw StateError(
      'Missing secret for transfer address $transferAddress. '
      'Initialize address manager with all tracked wormhole addresses before withdrawal.',
    );
  }

  /// Select transfers to cover the target amount.
  List<WormholeTransferInfo> _selectTransfers(List<WormholeTransferInfo> available, BigInt targetAmount) {
    // Sort by amount descending (largest first)
    final sorted = List<WormholeTransferInfo>.from(available)..sort((a, b) => b.amount.compareTo(a.amount));

    final selected = <WormholeTransferInfo>[];
    var total = BigInt.zero;

    for (final transfer in sorted) {
      if (total >= targetAmount) break;
      selected.add(transfer);
      total += transfer.amount;
    }

    return selected;
  }

  /// Generate a ZK proof for a single transfer.
  Future<GeneratedProof> _generateProofForTransfer({
    required WormholeProofGenerator generator,
    required WormholeService wormholeService,
    required WormholeTransferInfo transfer,
    required String secretHex,
    required String destinationAddress,
    required String rpcUrl,
    required String proofBlockHash,
    int? outputAmount,
    int changeAmount = 0,
    String? changeAddress,
  }) async {
    final blockHash = proofBlockHash.startsWith('0x') ? proofBlockHash : '0x$proofBlockHash';
    final secretAddress = wormholeService.deriveAddressFromSecret(secretHex);
    _debug(
      'proof input transferCount=${transfer.transferCount} amount=${transfer.amount} to=${transfer.wormholeAddress} from=${transfer.fundingAccount} blockHash=$blockHash secret=${_maskHex(secretHex)} secretAddress=$secretAddress',
    );
    if (secretAddress != transfer.wormholeAddress) {
      _debug(
        'WARNING secret/address mismatch transferAddress=${transfer.wormholeAddress} derivedFromSecret=$secretAddress',
      );
    }

    // Get block header for the proof block
    final blockHeader = await _fetchBlockHeader(rpcUrl, blockHash);

    // Get ZK Merkle proof for this transfer at the proof block
    // TODO: This needs a leaf_index from the transfer info
    final zkMerkleProof = await _fetchZkMerkleProof(
      rpcUrl: rpcUrl,
      blockHash: blockHash,
      transfer: transfer,
      secretHex: secretHex,
      wormholeService: wormholeService,
    );
    _debug(
      'proof dependencies blockNumber=${blockHeader.blockNumber} zkTreeRoot=${_shortHex(zkMerkleProof.zkTreeRootHex)} levels=${zkMerkleProof.siblingsHex.length}',
    );

    // Quantize the amount for the circuit
    final quantizedInputAmount = wormholeService.quantizeAmount(transfer.amount);

    // Compute the max output amount after fee deduction
    final maxOutputAmount = wormholeService.computeOutputAmount(quantizedInputAmount, feeBps);

    // Use provided output amount or default to max
    final quantizedOutputAmount = outputAmount ?? maxOutputAmount;

    // Validate that output + change doesn't exceed max
    if (quantizedOutputAmount + changeAmount > maxOutputAmount) {
      throw ArgumentError(
        'Output ($quantizedOutputAmount) + change ($changeAmount) exceeds max allowed ($maxOutputAmount)',
      );
    }

    // Create the UTXO with ZK Merkle proof data
    // TODO: Get leafIndex from transfer info or ZK Merkle proof
    final utxo = WormholeUtxo(
      secretHex: secretHex,
      inputAmount: quantizedInputAmount,
      transferCount: transfer.transferCount,
      leafIndex: BigInt.zero, // TODO: Get actual leaf index from transfer or proof
      blockHashHex: blockHash,
    );
    _debug(
      'utxo transferCount=${utxo.transferCount} inputAmount=${utxo.inputAmount} out=$quantizedOutputAmount change=$changeAmount',
    );

    // Create output assignment
    final ProofOutput output;
    if (changeAmount > 0 && changeAddress != null) {
      output = ProofOutput.withChange(
        amount: quantizedOutputAmount,
        exitAccount: destinationAddress,
        changeAmount: changeAmount,
        changeAccount: changeAddress,
      );
    } else {
      output = ProofOutput.single(amount: quantizedOutputAmount, exitAccount: destinationAddress);
    }

    // Generate the proof
    try {
      return await generator.generateProof(
        utxo: utxo,
        output: output,
        feeBps: feeBps,
        blockHeader: blockHeader,
        zkMerkleProof: zkMerkleProof,
      );
    } catch (e) {
      _debug(
        'generator.generateProof failed transferCount=${transfer.transferCount} blockNumber=${blockHeader.blockNumber} output=$quantizedOutputAmount change=$changeAmount error=$e',
      );
      rethrow;
    }
  }

  /// Fetch the current best block hash from the chain.
  Future<String> _fetchBestBlockHash(String rpcUrl) async {
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'chain_getBlockHash', 'params': []}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch best block hash: ${response.statusCode}');
    }

    final result = jsonDecode(response.body);
    if (result['error'] != null) {
      throw Exception('RPC error fetching best block hash: ${result['error']}');
    }

    final blockHash = result['result'] as String?;
    if (blockHash == null) {
      throw Exception('No best block hash returned from chain');
    }

    _debug('best block hash=$blockHash');
    return blockHash;
  }

  Future<String> _selectCommonProofBlockHash({
    required String rpcUrl,
    required List<WormholeTransferInfo> selectedTransfers,
  }) async {
    var maxTransferBlock = 0;
    for (final transfer in selectedTransfers) {
      final number = await _getBlockNumberByHash(rpcUrl, transfer.blockHash);
      if (number != null && number > maxTransferBlock) {
        maxTransferBlock = number;
      }
    }

    if (maxTransferBlock <= 0) {
      final best = await _fetchBestBlockHash(rpcUrl);
      _debug('proof block fallback to best (missing block numbers): $best');
      return best;
    }

    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'chain_getBlockHash',
          'params': [maxTransferBlock],
        }),
      );

      final result = jsonDecode(response.body);
      if (result['error'] != null) {
        throw Exception(result['error']);
      }

      final blockHash = result['result'] as String?;
      if (blockHash == null || blockHash.isEmpty) {
        throw Exception('No hash found for block $maxTransferBlock');
      }

      _debug('proof block selected from transfer max block=$maxTransferBlock hash=${_shortHex(blockHash)}');
      return blockHash;
    } catch (e) {
      final best = await _fetchBestBlockHash(rpcUrl);
      _debug('proof block lookup failed for block=$maxTransferBlock error=$e; fallback best=$best');
      return best;
    }
  }

  Future<int?> _getBlockNumberByHash(String rpcUrl, String blockHash) async {
    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'chain_getHeader',
          'params': [blockHash],
        }),
      );

      final result = jsonDecode(response.body);
      if (result['error'] != null) {
        return null;
      }

      final header = result['result'] as Map<String, dynamic>?;
      final numberHex = header?['number'] as String?;
      if (numberHex == null) {
        return null;
      }

      return int.parse(numberHex.substring(2), radix: 16);
    } catch (_) {
      return null;
    }
  }

  /// Fetch block header from RPC.
  Future<BlockHeader> _fetchBlockHeader(String rpcUrl, String blockHash) async {
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'chain_getHeader',
        'params': [blockHash],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch block header: ${response.statusCode}');
    }

    final result = jsonDecode(response.body);
    if (result['error'] != null) {
      throw Exception('RPC error fetching header for $blockHash: ${result['error']}');
    }

    final header = result['result'];
    if (header == null) {
      throw Exception('Block not found: $blockHash - the block may have been pruned or the chain was reset');
    }

    // Use SDK to properly encode digest from RPC logs
    final digestLogs = (header['digest']['logs'] as List<dynamic>? ?? []).cast<String>().toList();
    final wormholeService = WormholeService();
    final digestHex = wormholeService.encodeDigestFromRpcLogs(logsHex: digestLogs);

    final blockNumber = int.parse((header['number'] as String).substring(2), radix: 16);
    // TODO: Get zkTreeRoot from header when available
    final zkTreeRootHex = header['zkTreeRoot'] as String? ?? '0x' + '00' * 32;
    final recomputedHash = wormholeService.computeBlockHash(
      parentHashHex: header['parentHash'] as String,
      stateRootHex: header['stateRoot'] as String,
      extrinsicsRootHex: header['extrinsicsRoot'] as String,
      zkTreeRootHex: zkTreeRootHex,
      blockNumber: blockNumber,
      digestHex: digestHex,
    );
    final expectedHash = blockHash.toLowerCase();
    final actualHash = recomputedHash.toLowerCase();
    _debug(
      'header block=$blockNumber expectedHash=${_shortHex(expectedHash)} recomputedHash=${_shortHex(actualHash)} digestLogs=${digestLogs.length}',
    );
    if (actualHash != expectedHash) {
      _debug('WARNING block hash mismatch for header at $blockHash');
    }

    return BlockHeader(
      parentHashHex: header['parentHash'] as String,
      stateRootHex: header['stateRoot'] as String,
      extrinsicsRootHex: header['extrinsicsRoot'] as String,
      blockNumber: blockNumber,
      digestHex: digestHex,
    );
  }

  /// Fetch ZK Merkle proof for a transfer.
  ///
  /// TODO: This needs to be updated to use the zkTree_getMerkleProof RPC
  /// and return a ZkMerkleProof instead of the old StorageProof.
  Future<ZkMerkleProof> _fetchZkMerkleProof({
    required String rpcUrl,
    required String blockHash,
    required WormholeTransferInfo transfer,
    required String secretHex,
    required WormholeService wormholeService,
  }) async {
    // TODO: Implement zkTree_getMerkleProof RPC call for Planck
    // 1. Get the leaf_index from the transfer
    // 2. Call zkTree_getMerkleProof RPC with [leaf_index, block_hash]
    // 3. Parse the response (leaf_data, leaf_hash, siblings, root, depth)
    // 4. Return ZkMerkleProof with zkTreeRootHex, leafHashHex, siblingsHex
    throw UnimplementedError(
      'ZK Merkle proof fetching not yet implemented for Planck testnet. '
      'The withdrawal functionality needs to be updated to use zkTree_getMerkleProof RPC.',
    );
  }

  /// Submit aggregated proof to chain as an unsigned extrinsic.
  Future<String> _submitProof({required String proofHex}) async {
    final proofBytes = _hexToBytes(proofHex.startsWith('0x') ? proofHex.substring(2) : proofHex);

    final call = RuntimeCall.values.wormhole(wormhole_call.VerifyAggregatedProof(proofBytes: proofBytes));

    final txHash = await SubstrateService().submitUnsignedExtrinsic(call);
    final txHashHex = '0x${_bytesToHex(txHash)}';
    _debug('submit: RPC returned hash=$txHashHex (${txHash.length} bytes)');
    return txHashHex;
  }

  /// Wait for a transaction to be confirmed.
  ///
  /// Searches backwards through recent blocks for ProofVerified events,
  /// since on dev chains transactions may be included instantly before polling starts.
  Future<bool> _waitForTransactionConfirmation({
    required String txHash,
    required String rpcUrl,
    required String destinationAddress,
    required BigInt expectedAmount,
    int maxAttempts = 30,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final checkedBlocks = <String>{};

    _debug('confirm: waiting for withdrawal confirmation (tx=$txHash)');

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(pollInterval);
      }

      try {
        // Get latest block hash and search backwards
        final latestBlockHash = await _getLatestBlockHash(rpcUrl);
        if (latestBlockHash == null) {
          _debug('confirm: failed to get latest block hash');
          continue;
        }

        // Search backwards through recent blocks (up to 10 blocks back)
        String? currentBlockHash = latestBlockHash;
        for (var blockDepth = 0; blockDepth < 10 && currentBlockHash != null; blockDepth++) {
          if (checkedBlocks.contains(currentBlockHash)) {
            // Already checked this block, get parent and continue
            currentBlockHash = await _getParentBlockHash(rpcUrl, currentBlockHash);
            continue;
          }
          checkedBlocks.add(currentBlockHash);

          // Check for ProofVerified events in this block (don't require tx hash match)
          final result = await _checkBlockForProofVerified(rpcUrl: rpcUrl, blockHash: currentBlockHash);

          if (result != null) {
            return result;
          }

          // Get parent block hash
          currentBlockHash = await _getParentBlockHash(rpcUrl, currentBlockHash);
        }

        _debug(
          'confirm attempt=${attempt + 1}/$maxAttempts: checked ${checkedBlocks.length} blocks, no ProofVerified yet',
        );
      } catch (e) {
        _debug('confirm attempt=${attempt + 1}/$maxAttempts error=$e');
      }
    }

    return false;
  }

  /// Get the latest block hash.
  Future<String?> _getLatestBlockHash(String rpcUrl) async {
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'chain_getBlockHash', 'params': []}),
    );
    final result = jsonDecode(response.body);
    return result['result'] as String?;
  }

  /// Get parent block hash from a block.
  Future<String?> _getParentBlockHash(String rpcUrl, String blockHash) async {
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'chain_getBlock',
        'params': [blockHash],
      }),
    );
    final result = jsonDecode(response.body);
    return result['result']?['block']?['header']?['parentHash'] as String?;
  }

  /// Check a single block for ProofVerified events (without requiring tx hash match).
  /// Returns true if ProofVerified found, false if error found, null if no wormhole events.
  Future<bool?> _checkBlockForProofVerified({required String rpcUrl, required String blockHash}) async {
    // Check events in this block for wormhole activity
    final eventsKey = '0x${_twox128('System')}${_twox128('Events')}';
    final eventsResponse = await http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'state_getStorage',
        'params': [eventsKey, blockHash],
      }),
    );
    final eventsResult = jsonDecode(eventsResponse.body);
    final eventsHex = eventsResult['result'] as String?;

    if (eventsHex == null) {
      return null;
    }

    // Look for any ProofVerified event in this block (extrinsic index -1 means any)
    final wormholeResult = _checkForWormholeEvents(eventsHex, -1);

    if (wormholeResult != null) {
      _debug('confirm: found ProofVerified in block=$blockHash success=${wormholeResult['success']}');
      return wormholeResult['success'] == true;
    }

    return null;
  }

  /// Wormhole error names (order from pallet Error enum)
  static const _wormholeErrors = [
    'InvalidProof',
    'ProofDeserializationFailed',
    'VerificationFailed',
    'InvalidPublicInputs',
    'NullifierAlreadyUsed',
    'VerifierNotAvailable',
    'InvalidStorageRoot',
    'StorageRootMismatch',
    'BlockNotFound',
    'InvalidBlockNumber',
    'AggregatedVerifierNotAvailable',
    'AggregatedProofDeserializationFailed',
    'AggregatedVerificationFailed',
    'InvalidAggregatedPublicInputs',
    'InvalidVolumeFeeRate',
    'TransferAmountBelowMinimum',
  ];

  /// Check events hex for wormhole withdrawal verification activity.
  Map<String, dynamic>? _checkForWormholeEvents(String eventsHex, int extrinsicIndex) {
    final bytes = _hexToBytes(eventsHex.startsWith('0x') ? eventsHex.substring(2) : eventsHex);
    final input = scale.ByteInput(Uint8List.fromList(bytes));
    bool? success;
    String? error;

    try {
      final numEvents = scale.CompactCodec.codec.decode(input);

      for (var i = 0; i < numEvents; i++) {
        try {
          final eventRecord = EventRecord.decode(input);
          final phase = eventRecord.phase;
          // Skip if not ApplyExtrinsic phase
          if (phase is! system_phase.ApplyExtrinsic) {
            continue;
          }
          // If extrinsicIndex >= 0, filter by specific extrinsic; if -1, accept any
          if (extrinsicIndex >= 0 && phase.value0 != extrinsicIndex) {
            continue;
          }

          final event = eventRecord.event;

          // Check for Wormhole.ProofVerified
          if (event is runtime_event.Wormhole) {
            final wormholeEvent = event.value0;
            if (wormholeEvent is wormhole_event.ProofVerified) {
              success = true;
              _debug('event Wormhole.ProofVerified found');
            }
          }

          // Check for System.ExtrinsicFailed
          if (event is runtime_event.System) {
            final systemEvent = event.value0;
            if (systemEvent is system_event.ExtrinsicFailed) {
              success = false;
              error = _formatDispatchError(systemEvent.dispatchError);
              _debug('event System.ExtrinsicFailed error=$error');
            }
          }
        } catch (e) {
          _debug('event decode failed at index=$i: $e');
          break;
        }
      }
    } catch (e) {
      _debug('event blob decode failed: $e');
    }

    if (success == null) return null;

    return {'success': success, 'error': error};
  }

  /// Format a DispatchError into a human-readable string.
  String _formatDispatchError(dispatch_error.DispatchError err) {
    if (err is dispatch_error.Module) {
      final moduleError = err.value0;
      final palletIndex = moduleError.index;
      final errorIndex = moduleError.error.isNotEmpty ? moduleError.error[0] : 0;

      if (palletIndex == 20 && errorIndex < _wormholeErrors.length) {
        return 'Wormhole.${_wormholeErrors[errorIndex]}';
      }
      return 'Module(pallet=$palletIndex, error=$errorIndex)';
    }
    return err.toJson().toString();
  }

  // Helper functions

  String _twox128(String input) {
    final bytes = Uint8List.fromList(utf8.encode(input));
    final hash = Hasher.twoxx128.hash(bytes);
    return _bytesToHex(hash);
  }

  String _ss58ToHex(String ss58Address) {
    final decoded = ss58.Address.decode(ss58Address);
    return '0x${decoded.pubkey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Uint8List _hexToBytes(String hex) {
    final str = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(str.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(str.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _debug(String message) {
    if (!enableDebugLogs) {
      return;
    }
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    // ignore: avoid_print
    print('flutter: [$timestamp] [I] [Withdrawal] $message');
  }

  String _shortHex(String value) {
    final normalized = value.startsWith('0x') ? value : '0x$value';
    if (normalized.length <= 20) {
      return normalized;
    }
    return '${normalized.substring(0, 10)}...${normalized.substring(normalized.length - 8)}';
  }

  String _maskHex(String value) {
    final normalized = value.startsWith('0x') ? value : '0x$value';
    if (normalized.length <= 14) {
      return normalized;
    }
    return '${normalized.substring(0, 8)}...${normalized.substring(normalized.length - 4)}';
  }
}
