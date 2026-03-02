//! Wormhole address derivation and utilities for ZK proof-based token spending.
//!
//! This module provides functionality to:
//! - Derive wormhole addresses from a mnemonic using HD derivation
//! - Convert wormhole preimages to SS58 addresses
//!
//! ## Wormhole Address Derivation
//!
//! Wormhole addresses are derived using a two-step Poseidon hash:
//! 1. `first_hash` = Poseidon(salt || secret) where salt = "wormhole"
//! 2. `address` = Poseidon(first_hash)
//!
//! The `first_hash` is used as the rewards preimage (passed to the node via --rewards-preimage).
//! The `address` is the actual on-chain account that receives funds.
//!
//! ## HD Path Convention
//!
//! Wormhole secrets are derived using BIP44-style paths:
//! - Coin type: 189189189' (QUANTUS_WORMHOLE_CHAIN_ID)
//! - Full path: m/44'/189189189'/0'/{purpose}'/{index}'
//!
//! Purpose values:
//! - 0 = Mobile app wormhole sends (future)
//! - 1 = Miner rewards

use plonky2::field::types::PrimeField64;
use qp_rusty_crystals_hdwallet::{
    derive_wormhole_from_mnemonic, WormholePair, QUANTUS_WORMHOLE_CHAIN_ID,
};
use sp_core::crypto::{AccountId32, Ss58Codec};

/// Result of wormhole pair derivation
#[flutter_rust_bridge::frb(sync)]
pub struct WormholePairResult {
    /// The wormhole address as SS58 (the on-chain account)
    pub address: String,
    /// The raw address bytes (32 bytes, hex encoded)
    pub address_hex: String,
    /// The first hash / rewards preimage as SS58 (pass to --rewards-preimage)
    pub first_hash_ss58: String,
    /// The first hash / rewards preimage bytes (32 bytes, hex encoded)
    pub first_hash_hex: String,
    /// The secret bytes (32 bytes, hex encoded) - SENSITIVE, needed for ZK proofs
    pub secret_hex: String,
}

impl From<WormholePair> for WormholePairResult {
    fn from(pair: WormholePair) -> Self {
        let account = AccountId32::from(pair.address);
        let first_hash_account = AccountId32::from(pair.first_hash);

        WormholePairResult {
            address: account.to_ss58check(),
            address_hex: format!("0x{}", hex::encode(pair.address)),
            first_hash_ss58: first_hash_account.to_ss58check(),
            first_hash_hex: format!("0x{}", hex::encode(pair.first_hash)),
            secret_hex: format!("0x{}", hex::encode(pair.secret)),
        }
    }
}

/// Error type for wormhole operations
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug)]
pub struct WormholeError {
    pub message: String,
}

impl WormholeError {
    /// Returns the error message as a string for display.
    #[flutter_rust_bridge::frb(sync, name = "toString")]
    pub fn to_display_string(&self) -> String {
        format!("WormholeError: {}", self.message)
    }
}

impl std::fmt::Display for WormholeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for WormholeError {}

/// Derive a wormhole address pair from a mnemonic.
///
/// # Arguments
/// * `mnemonic` - The 24-word BIP39 mnemonic phrase
/// * `purpose` - The purpose index (0 = mobile sends, 1 = miner rewards)
/// * `index` - The address index within the purpose
///
/// # Returns
/// A `WormholePairResult` containing the address, first_hash, and secret.
///
/// # Example
/// ```ignore
/// let result = derive_wormhole_pair(
///     "word1 word2 ... word24".to_string(),
///     1,  // purpose: miner rewards
///     0,  // index: first address
/// )?;
/// println!("Rewards preimage (for --rewards-preimage): {}", result.first_hash_ss58);
/// println!("Wormhole address (on-chain account): {}", result.address);
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn derive_wormhole_pair(
    mnemonic: String,
    purpose: u32,
    index: u32,
) -> Result<WormholePairResult, WormholeError> {
    // Build the HD path: m/44'/189189189'/0'/{purpose}'/{index}'
    // Note: QUANTUS_WORMHOLE_CHAIN_ID already includes the apostrophe (189189189')
    let path = format!(
        "m/44'/{}/0'/{}'/{}'",
        QUANTUS_WORMHOLE_CHAIN_ID, purpose, index
    );

    let pair =
        derive_wormhole_from_mnemonic(&mnemonic, None, &path).map_err(|e| WormholeError {
            message: format!("Failed to derive wormhole pair: {:?}", e),
        })?;

    Ok(pair.into())
}

/// Convert a first_hash (rewards preimage) to its corresponding wormhole address.
///
/// This computes the address exactly as the chain and ZK circuit do:
/// - Convert first_hash (32 bytes) to 4 field elements using unsafe_digest_bytes_to_felts
///   (8 bytes per element)
/// - Hash once without padding using hash_variable_length
///
/// The wormhole address derivation is:
/// - secret -> hash(salt + secret) = first_hash (preimage for node)
/// - first_hash -> hash(first_hash) = address
///
/// # Arguments
/// * `first_hash_hex` - The first_hash bytes as hex string (with or without 0x prefix)
///
/// # Returns
/// The wormhole address as SS58 string.
#[flutter_rust_bridge::frb(sync)]
pub fn first_hash_to_address(first_hash_hex: String) -> Result<String, WormholeError> {
    let hex_str = first_hash_hex.trim_start_matches("0x");
    let first_hash_bytes: [u8; 32] = hex::decode(hex_str)
        .map_err(|e| WormholeError {
            message: format!("Invalid hex string: {}", e),
        })?
        .try_into()
        .map_err(|_| WormholeError {
            message: "First hash must be exactly 32 bytes".to_string(),
        })?;

    // The address is hash(first_hash) using the same method as the ZK circuit:
    // - unsafe_digest_bytes_to_felts: 32 bytes -> 4 field elements (8 bytes each)
    // - hash_variable_length: hash without padding
    use qp_poseidon_core::{hash_variable_length, serialization::unsafe_digest_bytes_to_felts};

    let first_hash_felts = unsafe_digest_bytes_to_felts(&first_hash_bytes);
    let address_bytes = hash_variable_length(first_hash_felts.to_vec());

    let account = AccountId32::from(address_bytes);
    Ok(account.to_ss58check())
}

/// Get the wormhole HD derivation path for a given purpose and index.
///
/// # Arguments
/// * `purpose` - The purpose index (0 = mobile sends, 1 = miner rewards)
/// * `index` - The address index within the purpose
///
/// # Returns
/// The full HD derivation path string.
#[flutter_rust_bridge::frb(sync)]
pub fn get_wormhole_derivation_path(purpose: u32, index: u32) -> String {
    format!(
        "m/44'/{}/0'/{}'/{}'",
        QUANTUS_WORMHOLE_CHAIN_ID, purpose, index
    )
}

/// Constants for wormhole derivation purposes
pub mod wormhole_purpose {
    /// Mobile app wormhole sends (future feature)
    pub const MOBILE_SENDS: u32 = 0;
    /// Miner rewards
    pub const MINER_REWARDS: u32 = 1;
}

// ============================================================================
// Proof Generation Types and Functions
// ============================================================================

/// A wormhole UTXO (unspent transaction output) - FFI-friendly version.
///
/// Represents an unspent wormhole deposit that can be used as input
/// for generating a proof.
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug, Clone)]
pub struct WormholeUtxo {
    /// The secret used to derive the wormhole address (hex encoded with 0x prefix).
    pub secret_hex: String,
    /// Amount in planck (12 decimal places).
    pub amount: u64, // Using u64 for FFI compatibility (actual is u128 but rewards are small)
    /// Transfer count from the NativeTransferred event.
    pub transfer_count: u64,
    /// The funding account (sender of the original transfer) - hex encoded.
    pub funding_account_hex: String,
    /// Block hash where the transfer was recorded - hex encoded.
    pub block_hash_hex: String,
}

/// Output assignment for a proof - where the funds go.
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug, Clone)]
pub struct ProofOutputAssignment {
    /// Amount for output 1 (quantized to 2 decimal places).
    pub output_amount_1: u32,
    /// Exit account for output 1 (SS58 address).
    pub exit_account_1: String,
    /// Amount for output 2 (quantized, 0 if unused).
    pub output_amount_2: u32,
    /// Exit account for output 2 (SS58 address, empty if unused).
    pub exit_account_2: String,
}

/// Block header data needed for proof generation.
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug, Clone)]
pub struct BlockHeaderData {
    /// Parent block hash (hex encoded).
    pub parent_hash_hex: String,
    /// State root of the block (hex encoded).
    pub state_root_hex: String,
    /// Extrinsics root of the block (hex encoded).
    pub extrinsics_root_hex: String,
    /// Block number.
    pub block_number: u32,
    /// Encoded digest (hex encoded, up to 110 bytes).
    pub digest_hex: String,
}

/// Storage proof data for the transfer.
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug, Clone)]
pub struct StorageProofData {
    /// Raw proof nodes from the state trie (each node is hex encoded).
    pub proof_nodes_hex: Vec<String>,
    /// State root the proof is against (hex encoded).
    pub state_root_hex: String,
}

/// Configuration loaded from circuit binaries directory.
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug, Clone, serde::Deserialize)]
pub struct CircuitConfig {
    /// Number of leaf proofs in an aggregation batch.
    pub num_leaf_proofs: usize,
}

impl CircuitConfig {
    /// Load configuration from a circuit binaries directory.
    pub fn load(bins_dir: &str) -> Result<Self, WormholeError> {
        let config_path = std::path::Path::new(bins_dir).join("config.json");
        let config_str = std::fs::read_to_string(&config_path).map_err(|e| WormholeError {
            message: format!(
                "Failed to read config from {}: {}",
                config_path.display(),
                e
            ),
        })?;

        serde_json::from_str(&config_str).map_err(|e| WormholeError {
            message: format!("Failed to parse config: {}", e),
        })
    }
}

/// Result of proof generation.
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug, Clone)]
pub struct GeneratedProof {
    /// The serialized proof bytes (hex encoded).
    pub proof_hex: String,
    /// The nullifier for this UTXO (hex encoded) - used to track spent UTXOs.
    pub nullifier_hex: String,
}

/// Result of proof aggregation.
#[flutter_rust_bridge::frb(sync)]
#[derive(Debug, Clone)]
pub struct AggregatedProof {
    /// The serialized aggregated proof bytes (hex encoded).
    pub proof_hex: String,
    /// Number of real proofs in the batch (rest are dummies).
    pub num_real_proofs: usize,
}

/// Compute the nullifier for a wormhole UTXO.
///
/// The nullifier is a deterministic hash of (secret, transfer_count) that prevents
/// double-spending. Once revealed on-chain, the UTXO cannot be spent again.
///
/// # Arguments
/// * `secret_hex` - The wormhole secret (32 bytes, hex with 0x prefix)
/// * `transfer_count` - The transfer count from NativeTransferred event
///
/// # Returns
/// The nullifier as hex string with 0x prefix.
#[flutter_rust_bridge::frb(sync)]
pub fn compute_nullifier(secret_hex: String, transfer_count: u64) -> Result<String, WormholeError> {
    let secret_bytes = parse_hex_32(&secret_hex)?;
    let secret: qp_zk_circuits_common::utils::BytesDigest =
        secret_bytes.try_into().map_err(|e| WormholeError {
            message: format!("Invalid secret bytes: {:?}", e),
        })?;

    let nullifier =
        qp_wormhole_circuit::nullifier::Nullifier::from_preimage(secret, transfer_count);
    let nullifier_bytes = qp_zk_circuits_common::utils::digest_felts_to_bytes(nullifier.hash);

    Ok(format!("0x{}", hex::encode(nullifier_bytes.as_ref())))
}

/// Derive the wormhole address from a secret.
///
/// This computes the unspendable account address that corresponds to the given secret.
///
/// # Arguments
/// * `secret_hex` - The wormhole secret (32 bytes, hex with 0x prefix)
///
/// # Returns
/// The wormhole address as SS58 string.
#[flutter_rust_bridge::frb(sync)]
pub fn derive_address_from_secret(secret_hex: String) -> Result<String, WormholeError> {
    let secret_bytes = parse_hex_32(&secret_hex)?;
    let secret: qp_zk_circuits_common::utils::BytesDigest =
        secret_bytes.try_into().map_err(|e| WormholeError {
            message: format!("Invalid secret bytes: {:?}", e),
        })?;

    let unspendable =
        qp_wormhole_circuit::unspendable_account::UnspendableAccount::from_secret(secret);
    let address_bytes = qp_zk_circuits_common::utils::digest_felts_to_bytes(unspendable.account_id);

    let account = AccountId32::from(
        <[u8; 32]>::try_from(address_bytes.as_ref()).expect("BytesDigest is always 32 bytes"),
    );
    Ok(account.to_ss58check())
}

/// Quantize an amount from planck (12 decimals) to the circuit format (2 decimals).
///
/// The circuit uses quantized amounts for privacy. This function converts
/// a full-precision amount to the quantized format.
///
/// # Arguments
/// * `amount_planck` - Amount in planck (smallest unit, 12 decimal places)
///
/// # Returns
/// Quantized amount (2 decimal places) that can be used in proof outputs.
#[flutter_rust_bridge::frb(sync)]
pub fn quantize_amount(amount_planck: u64) -> Result<u32, WormholeError> {
    // 12 decimals to 2 decimals = divide by 10^10
    const QUANTIZATION_FACTOR: u64 = 10_000_000_000; // 10^10

    let quantized = amount_planck / QUANTIZATION_FACTOR;

    if quantized > u32::MAX as u64 {
        return Err(WormholeError {
            message: format!("Amount too large to quantize: {}", amount_planck),
        });
    }

    Ok(quantized as u32)
}

/// Dequantize an amount from circuit format (2 decimals) back to planck (12 decimals).
///
/// # Arguments
/// * `quantized_amount` - Amount in circuit format (2 decimal places)
///
/// # Returns
/// Amount in planck (12 decimal places).
#[flutter_rust_bridge::frb(sync)]
pub fn dequantize_amount(quantized_amount: u32) -> u64 {
    const QUANTIZATION_FACTOR: u64 = 10_000_000_000; // 10^10
    quantized_amount as u64 * QUANTIZATION_FACTOR
}

/// Compute the output amount after fee deduction.
///
/// The circuit enforces that output amounts don't exceed input minus fee.
/// Use this function to compute the correct output amount for proof generation.
///
/// Formula: `output = input * (10000 - fee_bps) / 10000`
///
/// # Arguments
/// * `input_amount` - Input amount in quantized units (from quantize_amount)
/// * `fee_bps` - Fee rate in basis points (e.g., 10 = 0.1%)
///
/// # Returns
/// Maximum output amount in quantized units.
///
/// # Example
/// ```ignore
/// let input = quantize_amount(383561629241)?; // 38 in quantized
/// let output = compute_output_amount(input, 10); // 37 (after 0.1% fee)
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn compute_output_amount(input_amount: u32, fee_bps: u32) -> u32 {
    ((input_amount as u64) * (10000 - fee_bps as u64) / 10000) as u32
}

/// Get the batch size for proof aggregation.
///
/// # Arguments
/// * `bins_dir` - Path to circuit binaries directory
///
/// # Returns
/// Number of proofs that must be aggregated together.
#[flutter_rust_bridge::frb(sync)]
pub fn get_aggregation_batch_size(bins_dir: String) -> Result<usize, WormholeError> {
    let config = CircuitConfig::load(&bins_dir)?;
    Ok(config.num_leaf_proofs)
}

/// Encode digest logs from RPC format to SCALE-encoded bytes.
///
/// The RPC returns digest logs as an array of hex-encoded SCALE bytes.
/// This function properly encodes them as a SCALE Vec<DigestItem> which
/// matches what the circuit expects.
///
/// # Arguments
/// * `logs_hex` - Array of hex-encoded digest log items from RPC
///
/// # Returns
/// SCALE-encoded digest as hex string (with 0x prefix), padded/truncated to 110 bytes.
///
/// # Example
/// ```ignore
/// // From RPC: header.digest.logs = ["0x0642...", "0x0561..."]
/// let digest_hex = encode_digest_from_rpc_logs(vec!["0x0642...".into(), "0x0561...".into()])?;
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn encode_digest_from_rpc_logs(logs_hex: Vec<String>) -> Result<String, WormholeError> {
    use codec::Encode;

    // Each log is already a SCALE-encoded DigestItem
    // We need to encode them as Vec<DigestItem>: compact(length) ++ items
    let mut encoded = Vec::new();

    // Encode compact length prefix
    codec::Compact(logs_hex.len() as u32).encode_to(&mut encoded);

    // Append each log's raw bytes
    for log_hex in &logs_hex {
        let log_bytes = parse_hex(log_hex)?;
        encoded.extend_from_slice(&log_bytes);
    }

    // Pad or truncate to exactly 110 bytes (DIGEST_LOGS_SIZE)
    const DIGEST_LOGS_SIZE: usize = 110;
    let mut result = [0u8; DIGEST_LOGS_SIZE];
    let copy_len = encoded.len().min(DIGEST_LOGS_SIZE);
    result[..copy_len].copy_from_slice(&encoded[..copy_len]);

    Ok(format!("0x{}", hex::encode(result)))
}

/// Compute the full storage key for a wormhole TransferProof.
///
/// This key can be used with `state_getReadProof` RPC to fetch the Merkle proof
/// needed for ZK proof generation.
///
/// The storage key is: module_prefix ++ storage_prefix ++ poseidon_hash(key)
///
/// # Arguments
/// * `secret_hex` - The wormhole secret (32 bytes, hex with 0x prefix)
/// * `transfer_count` - The transfer count from NativeTransferred event
/// * `funding_account` - The account that sent the funds (SS58 format)
/// * `amount` - The exact transfer amount in planck
///
/// # Returns
/// The full storage key as hex string with 0x prefix.
#[flutter_rust_bridge::frb(sync)]
pub fn compute_transfer_proof_storage_key(
    secret_hex: String,
    transfer_count: u64,
    funding_account: String,
    amount: u64,
) -> Result<String, WormholeError> {
    // Compute wormhole address from secret
    let secret_bytes = parse_hex_32(&secret_hex)?;
    let secret_digest: qp_zk_circuits_common::utils::BytesDigest =
        secret_bytes.try_into().map_err(|e| WormholeError {
            message: format!("Invalid secret: {:?}", e),
        })?;

    let unspendable =
        qp_wormhole_circuit::unspendable_account::UnspendableAccount::from_secret(secret_digest);
    let unspendable_bytes =
        qp_zk_circuits_common::utils::digest_felts_to_bytes(unspendable.account_id);
    let wormhole_address: [u8; 32] = unspendable_bytes
        .as_ref()
        .try_into()
        .expect("BytesDigest is always 32 bytes");

    // Parse funding account
    let funding_account_bytes = ss58_to_bytes(&funding_account)?;

    // Compute the Poseidon hash of the storage key
    let leaf_hash = compute_transfer_proof_leaf_hash(
        0, // asset_id = 0 for native token
        transfer_count,
        &funding_account_bytes,
        &wormhole_address,
        amount as u128,
    )?;

    // Build the full storage key:
    // twox128("Wormhole") ++ twox128("TransferProof") ++ poseidon_hash
    //
    // Pre-computed twox128 hashes:
    // twox128("Wormhole") = 0x1cbfc5e0de51116eb98c56a3b9fd8c8b
    // twox128("TransferProof") = 0x4a4ee9c5fb3e0a4c6f3b6daa9b1c7b28
    //
    // Note: These hashes are computed using xxhash and are deterministic.
    // Using the standard Substrate storage prefix computation.
    use sp_core::twox_128;

    let module_prefix = twox_128(b"Wormhole");
    let storage_prefix = twox_128(b"TransferProof");

    let mut full_key = Vec::with_capacity(32 + 32);
    full_key.extend_from_slice(&module_prefix);
    full_key.extend_from_slice(&storage_prefix);
    full_key.extend_from_slice(&leaf_hash);

    Ok(format!("0x{}", hex::encode(full_key)))
}

// ============================================================================
// Proof Generator - Stateful wrapper for proof generation
// ============================================================================

use std::sync::Mutex;

/// Opaque handle to a proof generator.
///
/// The generator is expensive to initialize (loads ~171MB of circuit data),
/// so it should be created once and reused for all proof generations.
pub struct WormholeProofGenerator {
    pub bins_dir: String,
}

impl WormholeProofGenerator {
    /// Create a new proof generator from circuit files.
    ///
    /// # Arguments
    /// * `bins_dir` - Path to directory containing prover.bin and common.bin
    ///
    /// # Returns
    /// A new proof generator instance.
    pub fn new(bins_dir: String) -> Result<Self, WormholeError> {
        // Verify the circuit files exist
        let bins_path = std::path::Path::new(&bins_dir);
        let prover_path = bins_path.join("prover.bin");
        let common_path = bins_path.join("common.bin");

        if !prover_path.exists() {
            return Err(WormholeError {
                message: format!("prover.bin not found at {:?}", prover_path),
            });
        }
        if !common_path.exists() {
            return Err(WormholeError {
                message: format!("common.bin not found at {:?}", common_path),
            });
        }

        Ok(Self { bins_dir })
    }

    /// Generate a proof for a wormhole withdrawal.
    ///
    /// # Arguments
    /// * `utxo` - The UTXO to spend
    /// * `output` - Where to send the funds
    /// * `fee_bps` - Fee in basis points
    /// * `block_header` - Block header for the proof
    /// * `storage_proof` - Storage proof for the transfer
    ///
    /// # Returns
    /// The generated proof and nullifier.
    pub fn generate_proof(
        &self,
        utxo: WormholeUtxo,
        output: ProofOutputAssignment,
        fee_bps: u32,
        block_header: BlockHeaderData,
        storage_proof: StorageProofData,
    ) -> Result<GeneratedProof, WormholeError> {
        // Parse all hex inputs
        let secret = parse_hex_32(&utxo.secret_hex)?;
        let funding_account = parse_hex_32(&utxo.funding_account_hex)?;
        // Use the actual block hash from the chain (from the UTXO), not a computed one.
        // The circuit will verify this matches the hash of the header components.
        let block_hash = parse_hex_32(&utxo.block_hash_hex)?;

        let parent_hash = parse_hex_32(&block_header.parent_hash_hex)?;
        let state_root = parse_hex_32(&block_header.state_root_hex)?;
        let extrinsics_root = parse_hex_32(&block_header.extrinsics_root_hex)?;
        let digest = parse_hex(&block_header.digest_hex)?;

        let exit_account_1 = ss58_to_bytes(&output.exit_account_1)?;
        let exit_account_2 = if output.exit_account_2.is_empty() {
            [0u8; 32]
        } else {
            ss58_to_bytes(&output.exit_account_2)?
        };

        // Compute nullifier
        let secret_digest: qp_zk_circuits_common::utils::BytesDigest =
            secret.try_into().map_err(|e| WormholeError {
                message: format!("Invalid secret: {:?}", e),
            })?;
        let nullifier = qp_wormhole_circuit::nullifier::Nullifier::from_preimage(
            secret_digest,
            utxo.transfer_count,
        );
        let nullifier_bytes = qp_zk_circuits_common::utils::digest_felts_to_bytes(nullifier.hash);

        // Compute unspendable account
        let unspendable = qp_wormhole_circuit::unspendable_account::UnspendableAccount::from_secret(
            secret_digest,
        );
        let unspendable_bytes =
            qp_zk_circuits_common::utils::digest_felts_to_bytes(unspendable.account_id);

        // Process storage proof
        let proof_nodes: Vec<Vec<u8>> = storage_proof
            .proof_nodes_hex
            .iter()
            .map(|h| parse_hex(h))
            .collect::<Result<_, _>>()?;
        let storage_state_root = parse_hex_32(&storage_proof.state_root_hex)?;

        let wormhole_address: [u8; 32] = unspendable_bytes
            .as_ref()
            .try_into()
            .expect("BytesDigest is always 32 bytes");

        let processed_proof = qp_zk_circuits_common::storage_proof::prepare_proof_for_circuit(
            proof_nodes,
            hex::encode(storage_state_root),
            compute_transfer_proof_leaf_hash(
                0, // asset_id = 0 for native token
                utxo.transfer_count,
                &funding_account,
                &wormhole_address,
                utxo.amount as u128,
            )?,
        )
        .map_err(|e| WormholeError {
            message: format!("Storage proof preparation failed: {}", e),
        })?;

        // Quantize input amount
        let input_amount_quantized = quantize_amount(utxo.amount)?;

        // Prepare digest (padded to 110 bytes)
        const DIGEST_LOGS_SIZE: usize = 110;
        let mut digest_padded = [0u8; DIGEST_LOGS_SIZE];
        let copy_len = digest.len().min(DIGEST_LOGS_SIZE);
        digest_padded[..copy_len].copy_from_slice(&digest[..copy_len]);

        // NOTE: We use the actual block_hash from the UTXO (parsed above), not a computed one.
        // The circuit will verify that hash(header_components) == block_hash.

        // Build circuit inputs
        let private =
            qp_wormhole_circuit::inputs::PrivateCircuitInputs {
                secret: secret_digest,
                transfer_count: utxo.transfer_count,
                funding_account: funding_account.as_slice().try_into().map_err(|e| {
                    WormholeError {
                        message: format!("Invalid funding account: {:?}", e),
                    }
                })?,
                storage_proof: processed_proof,
                unspendable_account: unspendable_bytes,
                parent_hash: parent_hash
                    .as_slice()
                    .try_into()
                    .map_err(|e| WormholeError {
                        message: format!("Invalid parent hash: {:?}", e),
                    })?,
                state_root: state_root
                    .as_slice()
                    .try_into()
                    .map_err(|e| WormholeError {
                        message: format!("Invalid state root: {:?}", e),
                    })?,
                extrinsics_root: extrinsics_root.as_slice().try_into().map_err(|e| {
                    WormholeError {
                        message: format!("Invalid extrinsics root: {:?}", e),
                    }
                })?,
                digest: digest_padded,
                input_amount: input_amount_quantized,
            };

        let public =
            qp_wormhole_inputs::PublicCircuitInputs {
                asset_id: 0, // Native token
                output_amount_1: output.output_amount_1,
                output_amount_2: output.output_amount_2,
                volume_fee_bps: fee_bps,
                nullifier: nullifier_bytes,
                exit_account_1: exit_account_1.as_slice().try_into().map_err(|e| {
                    WormholeError {
                        message: format!("Invalid exit account 1: {:?}", e),
                    }
                })?,
                exit_account_2: exit_account_2.as_slice().try_into().map_err(|e| {
                    WormholeError {
                        message: format!("Invalid exit account 2: {:?}", e),
                    }
                })?,
                block_hash: block_hash
                    .as_slice()
                    .try_into()
                    .map_err(|e| WormholeError {
                        message: format!("Invalid block hash: {:?}", e),
                    })?,
                block_number: block_header.block_number,
            };

        let circuit_inputs = qp_wormhole_circuit::inputs::CircuitInputs { public, private };

        // Clone prover and generate proof
        let prover = self.clone_prover()?;
        let prover_with_inputs = prover.commit(&circuit_inputs).map_err(|e| WormholeError {
            message: format!("Failed to commit inputs: {}", e),
        })?;
        let proof = prover_with_inputs.prove().map_err(|e| WormholeError {
            message: format!("Proof generation failed: {}", e),
        })?;

        Ok(GeneratedProof {
            proof_hex: format!("0x{}", hex::encode(proof.to_bytes())),
            nullifier_hex: format!("0x{}", hex::encode(nullifier_bytes.as_ref())),
        })
    }

    /// Clone the internal prover by reloading from files.
    fn clone_prover(&self) -> Result<qp_wormhole_prover::WormholeProver, WormholeError> {
        let bins_path = std::path::Path::new(&self.bins_dir);
        let prover_path = bins_path.join("prover.bin");
        let common_path = bins_path.join("common.bin");

        qp_wormhole_prover::WormholeProver::new_from_files(&prover_path, &common_path).map_err(
            |e| WormholeError {
                message: format!("Failed to reload prover: {}", e),
            },
        )
    }
}

// ============================================================================
// Proof Aggregator
// ============================================================================

// Re-import the plonky2 types via qp_zk_circuits_common
use qp_zk_circuits_common::circuit::{C, D, F};
// Import plonky2 types for proof handling (qp-plonky2 is aliased as plonky2 in Cargo.toml)
// Use the same import paths as qp-wormhole-aggregator for type compatibility
use plonky2::plonk::circuit_data::CommonCircuitData;
use plonky2::plonk::proof::ProofWithPublicInputs;

/// Opaque handle to a proof aggregator.
///
/// The aggregator collects proofs and aggregates them into a single proof
/// for more efficient on-chain verification.
pub struct WormholeProofAggregator {
    inner: Mutex<qp_wormhole_aggregator::aggregator::WormholeProofAggregator>,
    common_data: CommonCircuitData<F, D>,
    batch_size: usize,
}

impl WormholeProofAggregator {
    /// Create a new proof aggregator from circuit files.
    ///
    /// # Arguments
    /// * `bins_dir` - Path to directory containing aggregator circuit files
    ///
    /// # Returns
    /// A new proof aggregator instance.
    pub fn new(bins_dir: String) -> Result<Self, WormholeError> {
        let bins_path = std::path::Path::new(&bins_dir);

        // Load config to get batch size
        let config = CircuitConfig::load(&bins_dir)?;
        let agg_config =
            qp_zk_circuits_common::aggregation::AggregationConfig::new(config.num_leaf_proofs);

        let aggregator =
            qp_wormhole_aggregator::aggregator::WormholeProofAggregator::from_prebuilt_dir(
                bins_path, agg_config,
            )
            .map_err(|e| WormholeError {
                message: format!("Failed to load aggregator from {:?}: {}", bins_dir, e),
            })?;

        let common_data = aggregator.leaf_circuit_data.common.clone();
        let batch_size = config.num_leaf_proofs;

        Ok(Self {
            inner: Mutex::new(aggregator),
            common_data,
            batch_size,
        })
    }

    /// Get the batch size (number of proofs per aggregation).
    pub fn batch_size(&self) -> usize {
        self.batch_size
    }

    /// Get the number of proofs currently in the buffer.
    pub fn proof_count(&self) -> Result<usize, WormholeError> {
        let aggregator = self.inner.lock().map_err(|e| WormholeError {
            message: format!("Failed to lock aggregator: {}", e),
        })?;
        Ok(aggregator
            .proofs_buffer
            .as_ref()
            .map(|b| b.len())
            .unwrap_or(0))
    }

    /// Add a proof to the aggregation buffer.
    ///
    /// # Arguments
    /// * `proof_hex` - The serialized proof bytes (hex encoded with 0x prefix)
    pub fn add_proof(&self, proof_hex: String) -> Result<(), WormholeError> {
        let proof_bytes = parse_hex(&proof_hex)?;

        let proof = ProofWithPublicInputs::<F, C, D>::from_bytes(proof_bytes, &self.common_data)
            .map_err(|e| WormholeError {
                message: format!("Failed to deserialize proof: {:?}", e),
            })?;

        // Debug: Log the block_hash from public inputs to verify it's not all zeros
        // Block hash is at indices 16-19 (4 field elements after asset_id, output_amount_1, output_amount_2, volume_fee_bps, nullifier[4], exit_1[4], exit_2[4])
        if proof.public_inputs.len() >= 20 {
            let block_hash: Vec<u64> = proof.public_inputs[16..20]
                .iter()
                .map(|f| f.to_canonical_u64())
                .collect();
            let is_dummy = block_hash.iter().all(|&v| v == 0);
            log::info!(
                "[SDK Aggregator] Adding proof with block_hash={:?}, is_dummy={}",
                block_hash,
                is_dummy
            );
        }

        let mut aggregator = self.inner.lock().map_err(|e| WormholeError {
            message: format!("Failed to lock aggregator: {}", e),
        })?;

        aggregator.push_proof(proof).map_err(|e| WormholeError {
            message: format!("Failed to add proof: {}", e),
        })
    }

    /// Aggregate all proofs in the buffer.
    ///
    /// If fewer than `batch_size` proofs have been added, the remaining
    /// slots are filled with dummy proofs automatically.
    ///
    /// # Returns
    /// The aggregated proof.
    pub fn aggregate(&self) -> Result<AggregatedProof, WormholeError> {
        let mut aggregator = self.inner.lock().map_err(|e| WormholeError {
            message: format!("Failed to lock aggregator: {}", e),
        })?;

        let num_real = aggregator
            .proofs_buffer
            .as_ref()
            .map(|b| b.len())
            .unwrap_or(0);

        log::info!(
            "[SDK Aggregator] Starting aggregation with {} real proofs, batch_size={}",
            num_real,
            self.batch_size
        );

        // Debug: Log block_hash of each proof in the buffer
        if let Some(ref proofs) = aggregator.proofs_buffer {
            for (i, proof) in proofs.iter().enumerate() {
                if proof.public_inputs.len() >= 20 {
                    let block_hash: Vec<u64> = proof.public_inputs[16..20]
                        .iter()
                        .map(|f| f.to_canonical_u64())
                        .collect();
                    let is_dummy = block_hash.iter().all(|&v| v == 0);
                    log::info!(
                        "[SDK Aggregator] Proof {} in buffer: block_hash={:?}, is_dummy={}",
                        i,
                        block_hash,
                        is_dummy
                    );
                }
            }
        }

        let result = aggregator.aggregate().map_err(|e| WormholeError {
            message: format!("Aggregation failed: {}", e),
        })?;

        Ok(AggregatedProof {
            proof_hex: format!("0x{}", hex::encode(result.proof.to_bytes())),
            num_real_proofs: num_real,
        })
    }

    /// Clear the proof buffer without aggregating.
    pub fn clear(&self) -> Result<(), WormholeError> {
        let mut aggregator = self.inner.lock().map_err(|e| WormholeError {
            message: format!("Failed to lock aggregator: {}", e),
        })?;

        aggregator.proofs_buffer = None;
        Ok(())
    }
}

// ============================================================================
// FFI Factory Functions
// ============================================================================

/// Create a new proof generator.
///
/// This loads ~171MB of circuit data, so it's expensive. Call once and reuse.
///
/// # Arguments
/// * `bins_dir` - Path to directory containing prover.bin and common.bin
pub fn create_proof_generator(bins_dir: String) -> Result<WormholeProofGenerator, WormholeError> {
    WormholeProofGenerator::new(bins_dir)
}

/// Create a new proof aggregator.
///
/// # Arguments
/// * `bins_dir` - Path to directory containing aggregator circuit files
pub fn create_proof_aggregator(bins_dir: String) -> Result<WormholeProofAggregator, WormholeError> {
    WormholeProofAggregator::new(bins_dir)
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Parse a hex string (with or without 0x prefix) into a 32-byte array.
fn parse_hex_32(hex_str: &str) -> Result<[u8; 32], WormholeError> {
    let hex_str = hex_str.trim_start_matches("0x");
    let bytes = hex::decode(hex_str).map_err(|e| WormholeError {
        message: format!("Invalid hex string: {}", e),
    })?;
    bytes.try_into().map_err(|_| WormholeError {
        message: "Expected 32 bytes".to_string(),
    })
}

/// Parse a hex string (with or without 0x prefix) into bytes.
fn parse_hex(hex_str: &str) -> Result<Vec<u8>, WormholeError> {
    let hex_str = hex_str.trim_start_matches("0x");
    hex::decode(hex_str).map_err(|e| WormholeError {
        message: format!("Invalid hex string: {}", e),
    })
}

/// Convert an SS58 address to a 32-byte account ID.
fn ss58_to_bytes(ss58: &str) -> Result<[u8; 32], WormholeError> {
    let account = AccountId32::from_ss58check(ss58).map_err(|e| WormholeError {
        message: format!("Invalid SS58 address '{}': {:?}", ss58, e),
    })?;
    Ok(account.into())
}

/// Compute the transfer proof leaf hash for storage proof verification.
///
/// Uses `hash_storage` to match the chain's PoseidonStorageHasher behavior,
/// which decodes the SCALE-encoded key and converts to felts via `ToFelts`.
fn compute_transfer_proof_leaf_hash(
    asset_id: u32,
    transfer_count: u64,
    funding_account: &[u8; 32],
    wormhole_address: &[u8; 32],
    amount: u128,
) -> Result<[u8; 32], WormholeError> {
    use codec::Encode;

    // TransferProofKey type on chain: (AssetId, TransferCount, AccountId, AccountId, Balance)
    // AccountId is [u8; 32] internally, and ToFelts is implemented for [u8; 32]
    type TransferProofKey = (u32, u64, [u8; 32], [u8; 32], u128);

    // SCALE encode the key tuple
    let key: TransferProofKey = (
        asset_id,
        transfer_count,
        *funding_account,
        *wormhole_address,
        amount,
    );
    let encoded = key.encode();

    // Use hash_storage which decodes and converts to felts via ToFelts trait
    // This matches how the chain's PoseidonStorageHasher works
    let hash = qp_poseidon::PoseidonHasher::hash_storage::<TransferProofKey>(&encoded);

    Ok(hash)
}

/// Compute block hash from header components.
///
/// This matches the Poseidon block hash computation used by the Quantus chain.
/// The hash is computed over the SCALE-encoded header components.
///
/// # Arguments
/// * `parent_hash_hex` - Parent block hash (32 bytes, hex with 0x prefix)
/// * `state_root_hex` - State root (32 bytes, hex with 0x prefix)
/// * `extrinsics_root_hex` - Extrinsics root (32 bytes, hex with 0x prefix)
/// * `block_number` - Block number
/// * `digest_hex` - SCALE-encoded digest (hex with 0x prefix, from encode_digest_from_rpc_logs)
///
/// # Returns
/// Block hash as hex string with 0x prefix.
#[flutter_rust_bridge::frb(sync)]
pub fn compute_block_hash(
    parent_hash_hex: String,
    state_root_hex: String,
    extrinsics_root_hex: String,
    block_number: u32,
    digest_hex: String,
) -> Result<String, WormholeError> {
    let parent_hash = parse_hex_32(&parent_hash_hex)?;
    let state_root = parse_hex_32(&state_root_hex)?;
    let extrinsics_root = parse_hex_32(&extrinsics_root_hex)?;
    let digest = parse_hex(&digest_hex)?;

    let hash = compute_block_hash_internal(
        &parent_hash,
        &state_root,
        &extrinsics_root,
        block_number,
        &digest,
    )?;

    Ok(format!("0x{}", hex::encode(hash)))
}

/// Internal function to compute block hash from raw bytes.
/// Delegates to the circuit's HeaderInputs to guarantee hash consistency with ZK proofs.
fn compute_block_hash_internal(
    parent_hash: &[u8; 32],
    state_root: &[u8; 32],
    extrinsics_root: &[u8; 32],
    block_number: u32,
    digest: &[u8],
) -> Result<[u8; 32], WormholeError> {
    use qp_wormhole_circuit::block_header::header::{HeaderInputs, DIGEST_LOGS_SIZE};
    use qp_wormhole_inputs::BytesDigest;

    let digest_fixed: [u8; DIGEST_LOGS_SIZE] = digest.try_into().map_err(|_| WormholeError {
        message: format!(
            "Digest must be {} bytes, got {}",
            DIGEST_LOGS_SIZE,
            digest.len()
        ),
    })?;

    let header = HeaderInputs::new(
        BytesDigest::try_from(*parent_hash).map_err(|e| WormholeError {
            message: format!("Invalid parent hash: {:?}", e),
        })?,
        block_number,
        BytesDigest::try_from(*state_root).map_err(|e| WormholeError {
            message: format!("Invalid state root: {:?}", e),
        })?,
        BytesDigest::try_from(*extrinsics_root).map_err(|e| WormholeError {
            message: format!("Invalid extrinsics root: {:?}", e),
        })?,
        &digest_fixed,
    )
    .map_err(|e| WormholeError {
        message: format!("Failed to create header inputs: {}", e),
    })?;

    let block_hash = header.block_hash();
    let hash: [u8; 32] = block_hash
        .as_ref()
        .try_into()
        .map_err(|_| WormholeError {
            message: "Block hash conversion failed".to_string(),
        })?;
    Ok(hash)

}

// ============================================================================
// Circuit Binary Generation
// ============================================================================

/// Result of circuit binary generation
#[flutter_rust_bridge::frb(sync)]
pub struct CircuitGenerationResult {
    /// Whether generation succeeded
    pub success: bool,
    /// Error message if failed
    pub error: Option<String>,
    /// Path to the generated binaries directory
    pub output_dir: Option<String>,
}

/// Progress callback for circuit generation (phase name, progress 0.0-1.0)
pub type CircuitGenerationProgress = extern "C" fn(phase: *const i8, progress: f64);

/// Generate circuit binary files for ZK proof generation.
///
/// This is a long-running operation (10-30 minutes) that generates the
/// circuit binaries needed for wormhole withdrawal proofs.
///
/// # Arguments
/// * `output_dir` - Directory to write the binaries to
/// * `num_leaf_proofs` - Number of leaf proofs per aggregation (typically 8)
///
/// # Returns
/// A `CircuitGenerationResult` indicating success or failure.
///
/// # Generated Files
/// - `prover.bin` - Prover circuit data (~163MB)
/// - `common.bin` - Common circuit data
/// - `verifier.bin` - Verifier circuit data
/// - `dummy_proof.bin` - Dummy proof for aggregation padding
/// - `aggregated_common.bin` - Aggregated circuit common data
/// - `aggregated_verifier.bin` - Aggregated circuit verifier data
/// - `config.json` - Configuration with hashes for integrity verification
pub fn generate_circuit_binaries(
    output_dir: String,
    num_leaf_proofs: u32,
) -> CircuitGenerationResult {
    match qp_wormhole_circuit_builder::generate_all_circuit_binaries(
        &output_dir,
        true, // include_prover - we need it for proof generation
        num_leaf_proofs as usize,
    ) {
        Ok(()) => CircuitGenerationResult {
            success: true,
            error: None,
            output_dir: Some(output_dir),
        },
        Err(e) => CircuitGenerationResult {
            success: false,
            error: Some(e.to_string()),
            output_dir: None,
        },
    }
}

/// Check if circuit binaries exist and are valid in a directory.
///
/// # Arguments
/// * `bins_dir` - Directory containing the circuit binaries
///
/// # Returns
/// True if all required files exist, false otherwise.
#[flutter_rust_bridge::frb(sync)]
pub fn check_circuit_binaries_exist(bins_dir: String) -> bool {
    use std::path::Path;

    let required_files = [
        "prover.bin",
        "common.bin",
        "verifier.bin",
        "dummy_proof.bin",
        "aggregated_common.bin",
        "aggregated_verifier.bin",
        "config.json",
    ];

    let path = Path::new(&bins_dir);
    if !path.exists() {
        return false;
    }

    for file in &required_files {
        if !path.join(file).exists() {
            return false;
        }
    }

    true
}

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_MNEMONIC: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art";

    #[test]
    fn test_derive_wormhole_pair() {
        let result = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 1, 0).unwrap();

        // Verify the result has the expected format
        assert!(result.address.starts_with("q") || result.address.starts_with("5"));
        assert!(result.address_hex.starts_with("0x"));
        assert_eq!(result.address_hex.len(), 66); // 0x + 64 hex chars
        assert!(result.first_hash_ss58.starts_with("q") || result.first_hash_ss58.starts_with("5"));
        assert!(result.first_hash_hex.starts_with("0x"));
        assert_eq!(result.first_hash_hex.len(), 66);
        assert!(result.secret_hex.starts_with("0x"));
        assert_eq!(result.secret_hex.len(), 66);
    }

    #[test]
    fn test_derive_deterministic() {
        // Same mnemonic + path should always produce the same result
        let result1 = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 1, 0).unwrap();
        let result2 = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 1, 0).unwrap();

        assert_eq!(result1.address, result2.address);
        assert_eq!(result1.first_hash_hex, result2.first_hash_hex);
        assert_eq!(result1.secret_hex, result2.secret_hex);
    }

    #[test]
    fn test_different_indices_produce_different_addresses() {
        let result0 = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 1, 0).unwrap();
        let result1 = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 1, 1).unwrap();

        assert_ne!(result0.address, result1.address);
        assert_ne!(result0.secret_hex, result1.secret_hex);
    }

    #[test]
    fn test_different_purposes_produce_different_addresses() {
        let result_miner = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 1, 0).unwrap();
        let result_mobile = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 0, 0).unwrap();

        assert_ne!(result_miner.address, result_mobile.address);
    }

    #[test]
    fn test_get_wormhole_derivation_path() {
        let path = get_wormhole_derivation_path(1, 5);
        assert!(path.contains("189189189'"));
        assert!(path.contains("/1'/"));
        assert!(path.contains("/5'"));
    }

    #[test]
    fn test_compute_nullifier_deterministic() {
        let secret = "0x0101010101010101010101010101010101010101010101010101010101010101";
        let n1 = compute_nullifier(secret.to_string(), 42).unwrap();
        let n2 = compute_nullifier(secret.to_string(), 42).unwrap();
        assert_eq!(n1, n2);
    }

    #[test]
    fn test_compute_nullifier_different_transfer_count() {
        let secret = "0x0101010101010101010101010101010101010101010101010101010101010101";
        let n1 = compute_nullifier(secret.to_string(), 1).unwrap();
        let n2 = compute_nullifier(secret.to_string(), 2).unwrap();
        assert_ne!(n1, n2);
    }

    #[test]
    fn test_quantize_amount() {
        // 1 QTN = 1_000_000_000_000 planck (12 decimals)
        // Quantized = 100 (2 decimals)
        let planck = 1_000_000_000_000u64;
        let quantized = quantize_amount(planck).unwrap();
        assert_eq!(quantized, 100);

        // Round trip
        let dequantized = dequantize_amount(quantized);
        assert_eq!(dequantized, planck);
    }

    #[test]
    fn test_derive_address_from_secret() {
        // Derive a pair and verify the address matches
        let pair = derive_wormhole_pair(TEST_MNEMONIC.to_string(), 1, 0).unwrap();
        let derived_addr = derive_address_from_secret(pair.secret_hex.clone()).unwrap();
        assert_eq!(derived_addr, pair.address);
    }

    #[test]
    fn test_block_hash_sdk_matches_circuit() {
        use qp_wormhole_circuit::block_header::header::HeaderInputs;
        use qp_wormhole_inputs::BytesDigest;

        let parent_hash = [0u8; 32];
        let block_number: u32 = 1;
        let state_root: [u8; 32] = hex::decode(
            "713c0468ddc5b657ce758a3fb75ec5ae906d95b334f24a4f5661cc775e1cdb43",
        )
        .unwrap()
        .try_into()
        .unwrap();
        let extrinsics_root = [0u8; 32];
        #[rustfmt::skip]
        let digest: [u8; 110] = [
            8, 6, 112, 111, 119, 95, 128, 233, 182, 183, 107, 158, 1, 115, 19, 219,
            126, 253, 86, 30, 208, 176, 70, 21, 45, 180, 229, 9, 62, 91, 4, 6, 53,
            245, 52, 48, 38, 123, 225, 5, 112, 111, 119, 95, 1, 1, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 18, 79, 226,
        ];
        #[rustfmt::skip]
        let expected: [u8; 32] = [
            160, 247, 232, 22, 150, 117, 245, 140, 3, 70, 175, 175, 22, 247, 90, 37,
            231, 80, 170, 11, 27, 183, 40, 51, 5, 19, 164, 19, 188, 192, 229, 212,
        ];

        let sdk_hash =
            compute_block_hash_internal(&parent_hash, &state_root, &extrinsics_root, block_number, &digest)
                .expect("SDK block hash computation failed");

        let circuit_hash = HeaderInputs::new(
            BytesDigest::try_from(parent_hash).unwrap(),
            block_number,
            BytesDigest::try_from(state_root).unwrap(),
            BytesDigest::try_from(extrinsics_root).unwrap(),
            &digest,
        )
        .unwrap()
        .block_hash();

        assert_eq!(
            circuit_hash.as_ref(),
            &expected,
            "Circuit hash sanity check against known fixture"
        );
        assert_eq!(
            sdk_hash, expected,
            "SDK hash must match the circuit's known block hash"
        );
    }

    #[test]
    fn test_block_hash_sdk_matches_circuit_nonzero_inputs() {
        use qp_wormhole_circuit::block_header::header::HeaderInputs;
        use qp_wormhole_inputs::BytesDigest;

        #[rustfmt::skip]
        let parent_hash: [u8; 32] = [
            160, 247, 232, 22, 150, 117, 245, 140, 3, 70, 175, 175, 22, 247, 90, 37,
            231, 80, 170, 11, 27, 183, 40, 51, 5, 19, 164, 19, 188, 192, 229, 212,
        ];
        let block_number: u32 = 2;
        let state_root: [u8; 32] = hex::decode(
            "2f10a7c86fdd3758d1174e955a5f6efbbef29b41850720853ee4843a2a0d48a7",
        )
        .unwrap()
        .try_into()
        .unwrap();
        let extrinsics_root = [0u8; 32];
        #[rustfmt::skip]
        let digest: [u8; 110] = [
            8, 6, 112, 111, 119, 95, 128, 233, 182, 183, 107, 158, 1, 115, 19, 219,
            126, 253, 86, 30, 208, 176, 70, 21, 45, 180, 229, 9, 62, 91, 4, 6, 53,
            245, 52, 48, 38, 123, 225, 5, 112, 111, 119, 95, 1, 1, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 18, 79, 226,
        ];
        #[rustfmt::skip]
        let expected: [u8; 32] = [
            123, 3, 1, 4, 129, 152, 164, 69, 52, 213, 96, 85, 78, 201, 4, 176, 26,
            84, 254, 144, 212, 78, 187, 6, 221, 141, 198, 216, 24, 52, 122, 31,
        ];

        let sdk_hash =
            compute_block_hash_internal(&parent_hash, &state_root, &extrinsics_root, block_number, &digest)
                .expect("SDK block hash computation failed");

        let circuit_hash = HeaderInputs::new(
            BytesDigest::try_from(parent_hash).unwrap(),
            block_number,
            BytesDigest::try_from(state_root).unwrap(),
            BytesDigest::try_from(extrinsics_root).unwrap(),
            &digest,
        )
        .unwrap()
        .block_hash();

        assert_eq!(
            circuit_hash.as_ref(),
            &expected,
            "Circuit hash sanity check against known fixture"
        );
        assert_eq!(
            sdk_hash, expected,
            "SDK hash must match the circuit's known block hash"
        );
    }
}
