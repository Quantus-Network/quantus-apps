import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole;

/// Purpose values for wormhole HD derivation.
class WormholePurpose {
  /// Mobile app wormhole sends (future feature).
  static const int mobileSends = 0;

  /// Miner rewards.
  static const int minerRewards = 1;
}

/// A wormhole key pair derived from a mnemonic.
class WormholeKeyPair {
  /// The wormhole address as SS58 (the on-chain account that receives funds).
  final String address;

  /// The raw address bytes (32 bytes, hex encoded with 0x prefix).
  final String addressHex;

  /// The first hash / rewards inner hash as SS58 (pass to node --rewards-inner-hash).
  final String rewardsPreimage;

  /// The first hash / rewards preimage bytes (32 bytes, hex encoded).
  final String rewardsPreimageHex;

  /// The secret bytes (32 bytes, hex encoded) - SENSITIVE, needed for ZK proofs.
  final String secretHex;

  const WormholeKeyPair({
    required this.address,
    required this.addressHex,
    required this.rewardsPreimage,
    required this.rewardsPreimageHex,
    required this.secretHex,
  });

  factory WormholeKeyPair.fromFfi(wormhole.WormholePairResult result) {
    return WormholeKeyPair(
      address: result.address,
      addressHex: result.addressHex,
      rewardsPreimage: result.firstHashSs58,
      rewardsPreimageHex: result.firstHashHex,
      secretHex: result.secretHex,
    );
  }
}

/// Service for wormhole address derivation and ZK proof generation.
///
/// Wormhole addresses are special addresses where no private key exists.
/// Instead, funds are spent using zero-knowledge proofs. This is used for
/// miner rewards in the Quantus blockchain.
///
/// ## Usage
///
/// ```dart
/// final service = WormholeService();
///
/// // Derive a wormhole key pair for miner rewards
/// final keyPair = service.deriveMinerRewardsKeyPair(mnemonic: mnemonic, index: 0);
///
/// // Use keyPair.rewardsPreimage for the node's --rewards-inner-hash flag
/// // Use keyPair.secretHex for generating withdrawal proofs
/// ```
class WormholeService {
  /// Derive a wormhole key pair from a mnemonic for miner rewards.
  ///
  /// This derives a wormhole address at the HD path:
  /// `m/44'/189189189'/0'/1'/{index}'`
  ///
  /// The returned key pair contains:
  /// - `address`: The on-chain wormhole address that will receive rewards
  /// - `rewardsPreimage`: The value to pass to `--rewards-inner-hash` when starting the miner node
  /// - `secretHex`: The secret needed for generating withdrawal proofs (keep secure!)
  WormholeKeyPair deriveMinerRewardsKeyPair({
    required String mnemonic,
    int index = 0,
  }) {
    final result = wormhole.deriveWormholePair(
      mnemonic: mnemonic,
      purpose: WormholePurpose.minerRewards,
      index: index,
    );
    return WormholeKeyPair.fromFfi(result);
  }

  /// Derive a wormhole key pair from a mnemonic with custom purpose.
  ///
  /// This derives a wormhole address at the HD path:
  /// `m/44'/189189189'/0'/{purpose}'/{index}'`
  ///
  /// Use [WormholePurpose.minerRewards] for miner reward addresses, or
  /// [WormholePurpose.mobileSends] for mobile app wormhole sends (future).
  WormholeKeyPair deriveKeyPair({
    required String mnemonic,
    required int purpose,
    int index = 0,
  }) {
    final result = wormhole.deriveWormholePair(
      mnemonic: mnemonic,
      purpose: purpose,
      index: index,
    );
    return WormholeKeyPair.fromFfi(result);
  }

  /// Convert a rewards preimage (first_hash) to its corresponding wormhole address.
  ///
  /// This is useful for verifying that a given preimage produces the expected address.
  String preimageToAddress(String preimageHex) {
    return wormhole.firstHashToAddress(firstHashHex: preimageHex);
  }

  /// Derive a wormhole address directly from a secret.
  ///
  /// This computes the on-chain address that corresponds to the given secret.
  String deriveAddressFromSecret(String secretHex) {
    return wormhole.deriveAddressFromSecret(secretHex: secretHex);
  }

  /// Compute the nullifier for a UTXO.
  ///
  /// The nullifier is a deterministic hash of (secret, transferCount) that
  /// prevents double-spending. Once revealed on-chain, the UTXO cannot be
  /// spent again.
  String computeNullifier({
    required String secretHex,
    required BigInt transferCount,
  }) {
    return wormhole.computeNullifier(
      secretHex: secretHex,
      transferCount: transferCount,
    );
  }

  /// Quantize an amount from planck (12 decimals) to circuit format (2 decimals).
  ///
  /// The ZK circuit uses quantized amounts for privacy. This function converts
  /// a full-precision amount to the quantized format.
  ///
  /// Example: 1 QTN = 1,000,000,000,000 planck → 100 quantized
  int quantizeAmount(BigInt amountPlanck) {
    return wormhole.quantizeAmount(amountPlanck: amountPlanck);
  }

  /// Dequantize an amount from circuit format (2 decimals) back to planck (12 decimals).
  ///
  /// Example: 100 quantized → 1,000,000,000,000 planck = 1 QTN
  BigInt dequantizeAmount(int quantizedAmount) {
    return wormhole.dequantizeAmount(quantizedAmount: quantizedAmount);
  }

  /// Compute the output amount after fee deduction.
  ///
  /// The ZK circuit enforces that output amounts don't exceed input minus fee.
  /// Use this function to compute the correct output amount for proof generation.
  ///
  /// Formula: `output = input * (10000 - fee_bps) / 10000`
  ///
  /// Example: `computeOutputAmount(38, 10)` = 37 (0.1% fee deducted)
  int computeOutputAmount(int inputAmount, int feeBps) {
    return wormhole.computeOutputAmount(
      inputAmount: inputAmount,
      feeBps: feeBps,
    );
  }

  /// Get the HD derivation path for a wormhole address.
  String getDerivationPath({required int purpose, required int index}) {
    return wormhole.getWormholeDerivationPath(purpose: purpose, index: index);
  }

  /// Get the aggregation batch size from circuit config.
  ///
  /// This is the number of proofs that must be aggregated together before
  /// submission to the chain.
  BigInt getAggregationBatchSize(String circuitBinsDir) {
    return wormhole.getAggregationBatchSize(binsDir: circuitBinsDir);
  }

  /// Create a proof generator for generating withdrawal proofs.
  ///
  /// This loads ~171MB of circuit data, so it's expensive. The generator
  /// should be created once and reused for all proof generations.
  ///
  /// [circuitBinsDir] should point to a directory containing `prover.bin`
  /// and `common.bin`.
  Future<WormholeProofGenerator> createProofGenerator(
    String circuitBinsDir,
  ) async {
    final generator = await wormhole.createProofGenerator(
      binsDir: circuitBinsDir,
    );
    return WormholeProofGenerator._(generator);
  }

  /// Create a proof aggregator for aggregating multiple proofs.
  ///
  /// Individual proofs must be aggregated before on-chain submission.
  ///
  /// [circuitBinsDir] should point to a directory containing the aggregator
  /// circuit files.
  Future<WormholeProofAggregator> createProofAggregator(
    String circuitBinsDir,
  ) async {
    final aggregator = await wormhole.createProofAggregator(
      binsDir: circuitBinsDir,
    );
    return WormholeProofAggregator._(aggregator);
  }

  /// Generate circuit binary files for ZK proof generation.
  ///
  /// This is a **long-running operation** (10-30 minutes on most devices) that
  /// generates the circuit binaries needed for wormhole withdrawal proofs.
  ///
  /// [outputDir] - Directory to write the binaries to
  /// [numLeafProofs] - Number of leaf proofs per aggregation (typically 8)
  ///
  /// Returns a [CircuitGenerationResult] indicating success or failure.
  ///
  /// Generated files (~163MB total):
  /// - `prover.bin` - Prover circuit data (largest file)
  /// - `common.bin` - Common circuit data
  /// - `verifier.bin` - Verifier circuit data
  /// - `dummy_proof.bin` - Dummy proof for aggregation padding
  /// - `aggregated_common.bin` - Aggregated circuit common data
  /// - `aggregated_verifier.bin` - Aggregated circuit verifier data
  /// - `config.json` - Configuration with hashes
  Future<wormhole.CircuitGenerationResult> generateCircuitBinaries({
    required String outputDir,
    int numLeafProofs = 8,
  }) {
    return wormhole.generateCircuitBinaries(
      outputDir: outputDir,
      numLeafProofs: numLeafProofs,
    );
  }

  /// Check if circuit binaries exist in a directory.
  ///
  /// Returns true if all required circuit files are present.
  bool checkCircuitBinariesExist(String binsDir) {
    return wormhole.checkCircuitBinariesExist(binsDir: binsDir);
  }

  /// Compute the full storage key for a wormhole TransferProof.
  ///
  /// This key can be used with `state_getReadProof` RPC to fetch the Merkle proof
  /// needed for ZK proof generation.
  ///
  /// The storage key is: twox128("Wormhole") ++ twox128("TransferProof") ++ poseidon_hash(key)
  ///
  /// Parameters:
  /// - [secretHex]: The wormhole secret (32 bytes, hex with 0x prefix)
  /// - [transferCount]: The transfer count from NativeTransferred event
  /// - [fundingAccount]: The account that sent the funds (SS58 format)
  /// - [amount]: The exact transfer amount in planck
  ///
  /// Encode digest logs from RPC format to SCALE-encoded bytes.
  ///
  /// The RPC returns digest logs as an array of hex-encoded SCALE bytes.
  /// This function properly encodes them as a SCALE Vec<DigestItem> which
  /// matches what the circuit expects.
  ///
  /// Parameters:
  /// - [logsHex]: Array of hex-encoded digest log items from RPC
  ///   (e.g., from `header.digest.logs` in the RPC response)
  ///
  /// Returns SCALE-encoded digest as hex string (with 0x prefix),
  /// padded/truncated to 110 bytes as required by the circuit.
  ///
  /// Example:
  /// ```dart
  /// // From RPC: header['digest']['logs'] = ['0x0642...', '0x0561...']
  /// final digestHex = service.encodeDigestFromRpcLogs(
  ///   logsHex: (header['digest']['logs'] as List).cast<String>(),
  /// );
  /// ```
  String encodeDigestFromRpcLogs({required List<String> logsHex}) {
    return wormhole.encodeDigestFromRpcLogs(logsHex: logsHex);
  }

  /// Compute block hash from header components.
  ///
  /// This matches the Poseidon block hash computation used by the Quantus chain.
  /// The hash is computed over the SCALE-encoded header components.
  ///
  /// Parameters:
  /// - [parentHashHex]: Parent block hash (32 bytes, hex with 0x prefix)
  /// - [stateRootHex]: State root (32 bytes, hex with 0x prefix)
  /// - [extrinsicsRootHex]: Extrinsics root (32 bytes, hex with 0x prefix)
  /// - [zkTreeRootHex]: ZK tree root (32 bytes, hex with 0x prefix)
  /// - [blockNumber]: Block number
  /// - [digestHex]: SCALE-encoded digest (from [encodeDigestFromRpcLogs])
  ///
  /// Returns block hash as hex string with 0x prefix.
  String computeBlockHash({
    required String parentHashHex,
    required String stateRootHex,
    required String extrinsicsRootHex,
    required String zkTreeRootHex,
    required int blockNumber,
    required String digestHex,
  }) {
    return wormhole.computeBlockHash(
      parentHashHex: parentHashHex,
      stateRootHex: stateRootHex,
      extrinsicsRootHex: extrinsicsRootHex,
      zkTreeRootHex: zkTreeRootHex,
      blockNumber: blockNumber,
      digestHex: digestHex,
    );
  }
}

/// A UTXO (unspent transaction output) from a wormhole address.
///
/// This represents funds that have been transferred to a wormhole address
/// and can be withdrawn using a ZK proof.
class WormholeUtxo {
  /// The wormhole secret (hex encoded with 0x prefix).
  final String secretHex;

  /// Input amount (quantized to 2 decimal places, as stored in ZK leaf).
  final int inputAmount;

  /// Transfer count from the NativeTransferred event.
  final BigInt transferCount;

  /// Leaf index in the ZK tree.
  final BigInt leafIndex;

  /// Block hash where the proof is anchored - hex encoded.
  final String blockHashHex;

  const WormholeUtxo({
    required this.secretHex,
    required this.inputAmount,
    required this.transferCount,
    required this.leafIndex,
    required this.blockHashHex,
  });

  wormhole.WormholeUtxo toFfi() {
    return wormhole.WormholeUtxo(
      secretHex: secretHex,
      inputAmount: inputAmount,
      transferCount: transferCount,
      leafIndex: leafIndex,
      blockHashHex: blockHashHex,
    );
  }
}

/// Output assignment for a proof - where the withdrawn funds should go.
class ProofOutput {
  /// Amount for the primary output (quantized to 2 decimal places).
  final int amount;

  /// Exit account for the primary output (SS58 address).
  final String exitAccount;

  /// Amount for the secondary output (change), 0 if unused.
  final int changeAmount;

  /// Exit account for the change, empty if unused.
  final String changeAccount;

  /// Create a single-output assignment (no change).
  const ProofOutput.single({required this.amount, required this.exitAccount})
    : changeAmount = 0,
      changeAccount = '';

  /// Create a dual-output assignment (spend + change).
  const ProofOutput.withChange({
    required this.amount,
    required this.exitAccount,
    required this.changeAmount,
    required this.changeAccount,
  });

  wormhole.ProofOutputAssignment toFfi() {
    return wormhole.ProofOutputAssignment(
      outputAmount1: amount,
      exitAccount1: exitAccount,
      outputAmount2: changeAmount,
      exitAccount2: changeAccount,
    );
  }
}

/// Block header data needed for proof generation.
class BlockHeader {
  /// Parent block hash (hex encoded).
  final String parentHashHex;

  /// State root of the block (hex encoded).
  final String stateRootHex;

  /// Extrinsics root of the block (hex encoded).
  final String extrinsicsRootHex;

  /// ZK tree root from block header (hex encoded).
  final String zkTreeRootHex;

  /// Block number.
  final int blockNumber;

  /// Encoded digest (hex encoded).
  final String digestHex;

  const BlockHeader({
    required this.parentHashHex,
    required this.stateRootHex,
    required this.extrinsicsRootHex,
    required this.zkTreeRootHex,
    required this.blockNumber,
    required this.digestHex,
  });

  wormhole.BlockHeaderData toFfi() {
    return wormhole.BlockHeaderData(
      parentHashHex: parentHashHex,
      stateRootHex: stateRootHex,
      extrinsicsRootHex: extrinsicsRootHex,
      blockNumber: blockNumber,
      digestHex: digestHex,
    );
  }
}

/// ZK Merkle proof data for verifying a transfer exists in the ZK tree.
class ZkMerkleProof {
  /// ZK tree root from block header (hex encoded, 32 bytes).
  final String zkTreeRootHex;

  /// Leaf hash (hex encoded, 32 bytes).
  final String leafHashHex;

  /// Unsorted sibling hashes at each level (3 siblings per level).
  /// Outer list = levels, inner list = 3 siblings per level (each hex encoded).
  final List<List<String>> siblingsHex;

  /// Raw leaf data (hex encoded).
  /// ZkLeaf structure: (to: AccountId32, transfer_count: u64, asset_id: u32, amount: u128)
  final String leafDataHex;

  const ZkMerkleProof({
    required this.zkTreeRootHex,
    required this.leafHashHex,
    required this.siblingsHex,
    required this.leafDataHex,
  });

  /// Decode the quantized input amount from the leaf data.
  /// The leaf stores the raw amount in planck, but we need to quantize it for the circuit.
  int get inputAmount {
    // ZkLeaf is: (AccountId32, u64, u32, u128)
    // AccountId32 = 32 bytes
    // u64 = 8 bytes (transfer_count)
    // u32 = 4 bytes (asset_id)
    // u128 = 16 bytes (amount - RAW in planck)
    // Total = 60 bytes
    final hex = leafDataHex.startsWith('0x')
        ? leafDataHex.substring(2)
        : leafDataHex;
    final bytes = List<int>.generate(
      hex.length ~/ 2,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    );

    if (bytes.length < 60) {
      throw Exception(
        'Invalid leaf data length: expected at least 60 bytes, got ${bytes.length}',
      );
    }

    // The amount is bytes 44-60 (u128, little-endian)
    BigInt rawAmount = BigInt.zero;
    for (int i = 0; i < 16; i++) {
      rawAmount += BigInt.from(bytes[44 + i]) << (8 * i);
    }

    // Quantize: divide by 10^10 to go from 12 decimals to 2 decimals
    final quantized = rawAmount ~/ BigInt.from(10000000000);
    return quantized.toInt();
  }

  wormhole.ZkMerkleProofData toFfi() {
    return wormhole.ZkMerkleProofData(
      zkTreeRootHex: zkTreeRootHex,
      leafHashHex: leafHashHex,
      siblingsHex: siblingsHex,
      leafDataHex: leafDataHex,
    );
  }
}

/// Result of generating a ZK proof.
class GeneratedProof {
  /// The serialized proof bytes (hex encoded).
  final String proofHex;

  /// The nullifier for this UTXO (hex encoded).
  /// Once submitted on-chain, this UTXO cannot be spent again.
  final String nullifierHex;

  const GeneratedProof({required this.proofHex, required this.nullifierHex});

  factory GeneratedProof.fromFfi(wormhole.GeneratedProof result) {
    return GeneratedProof(
      proofHex: result.proofHex,
      nullifierHex: result.nullifierHex,
    );
  }
}

/// Result of aggregating multiple proofs.
class AggregatedProof {
  /// The serialized aggregated proof bytes (hex encoded).
  final String proofHex;

  /// Number of real proofs in the batch (rest are dummy proofs).
  final int numRealProofs;

  const AggregatedProof({required this.proofHex, required this.numRealProofs});

  factory AggregatedProof.fromFfi(wormhole.AggregatedProof result) {
    return AggregatedProof(
      proofHex: result.proofHex,
      numRealProofs: result.numRealProofs.toInt(),
    );
  }
}

/// Generates ZK proofs for wormhole withdrawals.
///
/// Creating a generator is expensive (loads ~171MB of circuit data),
/// so reuse the same instance for multiple proof generations.
class WormholeProofGenerator {
  final wormhole.WormholeProofGenerator _inner;

  WormholeProofGenerator._(this._inner);

  /// Generate a ZK proof for withdrawing from a wormhole address.
  ///
  /// This proves that the caller knows the secret for the UTXO without
  /// revealing it.
  ///
  /// Parameters:
  /// - [utxo]: The UTXO to spend
  /// - [output]: Where to send the funds
  /// - [feeBps]: Fee in basis points (e.g., 100 = 1%)
  /// - [blockHeader]: Block header data for the proof
  /// - [zkMerkleProof]: ZK Merkle proof that the UTXO exists in the tree
  ///
  /// Returns the generated proof and its nullifier.
  Future<GeneratedProof> generateProof({
    required WormholeUtxo utxo,
    required ProofOutput output,
    required int feeBps,
    required BlockHeader blockHeader,
    required ZkMerkleProof zkMerkleProof,
  }) async {
    final result = await _inner.generateProof(
      utxo: utxo.toFfi(),
      output: output.toFfi(),
      feeBps: feeBps,
      blockHeader: blockHeader.toFfi(),
      zkMerkleProof: zkMerkleProof.toFfi(),
    );
    return GeneratedProof.fromFfi(result);
  }
}

/// Aggregates multiple proofs into a single proof for on-chain submission.
///
/// Individual proofs must be aggregated before submission to the chain.
/// If fewer proofs than the batch size are added, dummy proofs are used
/// to fill the remaining slots.
class WormholeProofAggregator {
  final wormhole.WormholeProofAggregator _inner;

  WormholeProofAggregator._(this._inner);

  /// Get the batch size (number of proofs per aggregation).
  Future<int> get batchSize async {
    final size = await _inner.batchSize();
    return size.toInt();
  }

  /// Get the number of proofs currently in the buffer.
  Future<int> get proofCount async {
    final count = await _inner.proofCount();
    return count.toInt();
  }

  /// Add a proof to the aggregation buffer.
  Future<void> addProof(String proofHex) async {
    await _inner.addProof(proofHex: proofHex);
  }

  /// Add a generated proof to the aggregation buffer.
  Future<void> addGeneratedProof(GeneratedProof proof) async {
    await _inner.addProof(proofHex: proof.proofHex);
  }

  /// Aggregate all proofs in the buffer.
  ///
  /// If fewer than [batchSize] proofs have been added, the remaining
  /// slots are filled with dummy proofs automatically.
  ///
  /// Returns the aggregated proof ready for on-chain submission.
  Future<AggregatedProof> aggregate() async {
    final result = await _inner.aggregate();
    return AggregatedProof.fromFfi(result);
  }

  /// Clear the proof buffer without aggregating.
  Future<void> clear() async {
    await _inner.clear();
  }
}
