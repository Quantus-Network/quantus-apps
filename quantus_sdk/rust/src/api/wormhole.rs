use qp_wormhole_circuit::{
    inputs::{CircuitInputs, PrivateCircuitInputs},
    nullifier::Nullifier,
    sensitive::Secret,
};
use qp_wormhole_inputs::{BytesDigest, PublicCircuitInputs};
use qp_zk_circuits_common::{
    utils::digest_to_bytes,
    zk_merkle::{hash_node_presorted, SIBLINGS_PER_LEVEL},
};
use std::path::{Path, PathBuf};

pub const ZK_CIRCUITS_VERSION: &str = "4.2.0";

fn versioned_bins_dir(base: &Path) -> PathBuf {
    base.join(format!("v{}", ZK_CIRCUITS_VERSION))
}

const LEGACY_FILES: &[&str] = &[
    "common.bin",
    "verifier.bin",
    "dummy_proof.bin",
    "private_batch_common.bin",
    "private_batch_verifier.bin",
    "private_batch_prover.bin",
    "prover.bin",
    "config.json",
];

fn cleanup_stale_circuit_dirs(base: &Path) {
    for name in LEGACY_FILES {
        let path = base.join(name);
        if path.exists() {
            eprintln!("[circuits] removing legacy file: {}", path.display());
            if let Err(e) = std::fs::remove_file(&path) {
                eprintln!("[circuits] failed to remove {}: {}", path.display(), e);
            }
        }
    }

    let current = format!("v{}", ZK_CIRCUITS_VERSION);
    let entries = match std::fs::read_dir(base) {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if name_str.starts_with('v') && name_str != current && entry.path().is_dir() {
            eprintln!("[circuits] removing old version dir: {}", entry.path().display());
            if let Err(e) = std::fs::remove_dir_all(entry.path()) {
                eprintln!("[circuits] failed to remove {}: {}", entry.path().display(), e);
            }
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn zk_circuits_version() -> String {
    ZK_CIRCUITS_VERSION.to_string()
}

#[flutter_rust_bridge::frb(sync)]
pub fn compute_address_hash_hex(raw_address: Vec<u8>) -> Result<String, String> {
    let bytes: [u8; 32] = raw_address
        .try_into()
        .map_err(|_| "Address must be exactly 32 bytes".to_string())?;
    let hash = blake3::hash(&bytes);
    Ok(hex::encode(hash.as_bytes()))
}

pub const NATIVE_ASSET_ID: u32 = 0;
pub const VOLUME_FEE_BPS: u32 = 10;
pub const SCALE_DOWN_FACTOR: u128 = 10_000_000_000;
// Must match the chain's aggregation batch size (num_n=7 since v0.7.1-q-day-2).
pub const DEFAULT_NUM_LEAF_PROOFS: usize = 7;

#[flutter_rust_bridge::frb(sync)]
pub struct ProofInput {
    pub secret: Vec<u8>,
    pub transfer_count: u64,
    pub wormhole_address: Vec<u8>,
    pub input_amount: u32,
    pub block_hash: Vec<u8>,
    pub block_number: u32,
    pub parent_hash: Vec<u8>,
    pub state_root: Vec<u8>,
    pub extrinsics_root: Vec<u8>,
    pub digest: Vec<u8>,
    pub zk_tree_root: Vec<u8>,
    pub sorted_siblings_flat: Vec<u8>,
    pub positions: Vec<u8>,
    pub exit_account_1: Vec<u8>,
    pub output_amount_1: u32,
    pub exit_account_2: Vec<u8>,
    pub output_amount_2: u32,
    pub volume_fee_bps: u32,
    pub asset_id: u32,
}

#[flutter_rust_bridge::frb(sync)]
pub struct ProofOutput {
    pub proof_bytes: Vec<u8>,
    pub nullifier: Vec<u8>,
}

#[flutter_rust_bridge::frb(sync)]
pub struct MerkleProcessed {
    pub sorted_siblings_flat: Vec<u8>,
    pub positions: Vec<u8>,
}

fn vec_to_32(v: &[u8], name: &str) -> Result<[u8; 32], String> {
    v.try_into()
        .map_err(|_| format!("{} must be exactly 32 bytes, got {}", name, v.len()))
}

fn vec_to_digest(v: &[u8], name: &str) -> Result<BytesDigest, String> {
    let arr = vec_to_32(v, name)?;
    arr.try_into()
        .map_err(|e| format!("Failed to convert {} to digest: {:?}", name, e))
}

#[flutter_rust_bridge::frb(sync)]
pub fn compute_nullifier(secret: Vec<u8>, transfer_count: u64) -> Result<Vec<u8>, String> {
    let secret_digest = vec_to_digest(&secret, "secret")?;
    let nullifier = Nullifier::from_preimage(secret_digest, transfer_count);
    Ok(digest_to_bytes(nullifier.hash).to_vec())
}

#[flutter_rust_bridge::frb(sync)]
pub fn compute_wormhole_address(secret: Vec<u8>) -> Result<Vec<u8>, String> {
    let secret_digest = vec_to_digest(&secret, "secret")?;
    let unspendable =
        qp_wormhole_circuit::unspendable_account::UnspendableAccount::from_secret(secret_digest);
    Ok(digest_to_bytes(unspendable.account_id).to_vec())
}

#[flutter_rust_bridge::frb(sync)]
pub fn wormhole_compute_output_amount(input_amount: u32, fee_bps: u32) -> Result<u32, String> {
    let factor = 10_000u64
        .checked_sub(fee_bps as u64)
        .ok_or_else(|| format!("fee_bps must be <= 10000, got {}", fee_bps))?;
    let output = (input_amount as u64)
        .checked_mul(factor)
        .ok_or_else(|| "Output amount overflow".to_string())?
        / 10_000;
    u32::try_from(output).map_err(|_| "Output amount exceeds u32 range".to_string())
}

#[flutter_rust_bridge::frb(sync)]
pub fn decode_leaf_amount(leaf_data: Vec<u8>) -> Result<u32, String> {
    if leaf_data.len() < 60 {
        return Err(format!(
            "Invalid leaf data length: expected >= 60, got {}",
            leaf_data.len()
        ));
    }
    let amount_bytes: [u8; 16] = leaf_data[44..60]
        .try_into()
        .map_err(|_| "Failed to extract amount bytes".to_string())?;
    let raw_amount = u128::from_le_bytes(amount_bytes);
    let scaled = raw_amount / SCALE_DOWN_FACTOR;
    u32::try_from(scaled)
        .map_err(|_| format!("Leaf amount {} exceeds u32 range after scaling", scaled))
}

#[flutter_rust_bridge::frb(sync)]
pub fn decode_leaf_transfer_count(leaf_data: Vec<u8>) -> Result<u64, String> {
    if leaf_data.len() < 40 {
        return Err(format!(
            "Invalid leaf data length: expected >= 40, got {}",
            leaf_data.len()
        ));
    }
    let tc_bytes: [u8; 8] = leaf_data[32..40]
        .try_into()
        .map_err(|_| "Failed to extract transfer_count bytes".to_string())?;
    Ok(u64::from_le_bytes(tc_bytes))
}

#[flutter_rust_bridge::frb(sync)]
pub fn decode_leaf_to_account(leaf_data: Vec<u8>) -> Result<Vec<u8>, String> {
    if leaf_data.len() < 32 {
        return Err(format!(
            "Invalid leaf data length: expected >= 32, got {}",
            leaf_data.len()
        ));
    }
    Ok(leaf_data[0..32].to_vec())
}

#[flutter_rust_bridge::frb(sync)]
pub fn compute_merkle_positions(
    unsorted_siblings_flat: Vec<u8>,
    leaf_hash: Vec<u8>,
    depth: u32,
) -> Result<MerkleProcessed, String> {
    let depth = depth as usize;
    let expected_len = depth * SIBLINGS_PER_LEVEL * 32;
    if unsorted_siblings_flat.len() != expected_len {
        return Err(format!(
            "Expected {} bytes for {} levels, got {}",
            expected_len,
            depth,
            unsorted_siblings_flat.len()
        ));
    }

    let leaf_hash_arr = vec_to_32(&leaf_hash, "leaf_hash")?;

    let mut unsorted_siblings: Vec<[[u8; 32]; SIBLINGS_PER_LEVEL]> = Vec::with_capacity(depth);
    for level in 0..depth {
        let base = level * SIBLINGS_PER_LEVEL * 32;
        let mut sibs = [[0u8; 32]; SIBLINGS_PER_LEVEL];
        for s in 0..SIBLINGS_PER_LEVEL {
            let start = base + s * 32;
            sibs[s] = unsorted_siblings_flat[start..start + 32]
                .try_into()
                .map_err(|_| format!("Failed to parse sibling at level {} idx {}", level, s))?;
        }
        unsorted_siblings.push(sibs);
    }

    let mut current_hash = leaf_hash_arr;
    let mut sorted_out: Vec<u8> = Vec::with_capacity(expected_len);
    let mut positions_out: Vec<u8> = Vec::with_capacity(depth);

    for level_siblings in unsorted_siblings.iter() {
        let mut all_four: [[u8; 32]; 4] = [
            current_hash,
            level_siblings[0],
            level_siblings[1],
            level_siblings[2],
        ];
        all_four.sort();

        let pos = all_four
            .iter()
            .position(|h| *h == current_hash)
            .expect("current hash must be in the array") as u8;
        positions_out.push(pos);

        let mut sib_idx = 0;
        for (i, h) in all_four.iter().enumerate() {
            if i as u8 != pos {
                sorted_out.extend_from_slice(h);
                sib_idx += 1;
                if sib_idx >= SIBLINGS_PER_LEVEL {
                    break;
                }
            }
        }

        current_hash = hash_node_presorted(&all_four)
            .map_err(|e| format!("Failed to hash merkle node at level: {}", e))?;
    }

    Ok(MerkleProcessed {
        sorted_siblings_flat: sorted_out,
        positions: positions_out,
    })
}

pub fn ensure_circuit_binaries(bins_dir: String) -> Result<String, String> {
    let base = Path::new(&bins_dir);
    std::fs::create_dir_all(base)
        .map_err(|e| format!("Failed to create bins directory {}: {}", bins_dir, e))?;

    cleanup_stale_circuit_dirs(base);

    let dir = versioned_bins_dir(base);
    std::fs::create_dir_all(&dir)
        .map_err(|e| format!("Failed to create versioned bins directory {}: {}", dir.display(), e))?;

    let config_path = dir.join("config.json");
    if all_required_files_exist(&dir) {
        match qp_wormhole_circuit_builder::CircuitBinsConfig::load(&dir) {
            Ok(config) if config.num_leaf_proofs == DEFAULT_NUM_LEAF_PROOFS => {
                return std::fs::read_to_string(&config_path)
                    .map_err(|e| format!("Failed to read config.json: {}", e));
            }
            _ => {}
        }
    }

    qp_wormhole_circuit_builder::generate_all_circuit_binaries(
        &dir,
        true,
        DEFAULT_NUM_LEAF_PROOFS,
        None,
    )
    .map_err(|e| format!("Circuit binary generation failed: {}", e))?;

    let config_str = std::fs::read_to_string(&config_path)
        .map_err(|e| format!("Failed to read config.json after generation: {}", e))?;
    Ok(config_str)
}

fn all_required_files_exist(dir: &Path) -> bool {
    // Must match the artifacts produced by `generate_all_circuit_binaries` in
    // qp-wormhole-* 4.2.x. No circuit emits a prover binary anymore (provers
    // always rebuild their circuits from source), so `private_batch_prover.bin`
    // is gone; `PrivateBatchProver::new_from_binaries_dir` now loads only
    // common.bin, verifier.bin, dummy_proof.bin and config.json. Keeping the
    // removed prover file in this list makes the check never pass, forcing a
    // full (expensive) circuit regeneration on every call.
    const REQUIRED: &[&str] = &[
        "common.bin",
        "verifier.bin",
        "dummy_proof.bin",
        "private_batch_common.bin",
        "private_batch_verifier.bin",
        "config.json",
    ];
    REQUIRED.iter().all(|f| dir.join(f).exists())
}

pub fn generate_proof(
    input: ProofInput,
    _prover_bin_path: String,
    _common_bin_path: String,
) -> Result<ProofOutput, String> {
    let secret_digest = vec_to_digest(&input.secret, "secret")?;
    let wormhole_address = vec_to_32(&input.wormhole_address, "wormhole_address")?;

    let nullifier = Nullifier::from_preimage(secret_digest, input.transfer_count);
    let nullifier_bytes = digest_to_bytes(nullifier.hash);

    let unspendable =
        qp_wormhole_circuit::unspendable_account::UnspendableAccount::from_secret(secret_digest);
    let unspendable_bytes = digest_to_bytes(unspendable.account_id);

    if *unspendable_bytes != wormhole_address {
        return Err(
            "Wormhole address doesn't match computed unspendable account from secret".to_string(),
        );
    }

    const DIGEST_LOGS_SIZE: usize = 110;
    let mut digest_padded = [0u8; DIGEST_LOGS_SIZE];
    let copy_len = input.digest.len().min(DIGEST_LOGS_SIZE);
    digest_padded[..copy_len].copy_from_slice(&input.digest[..copy_len]);

    let depth = input.positions.len();
    let mut zk_merkle_siblings: Vec<[[u8; 32]; SIBLINGS_PER_LEVEL]> = Vec::with_capacity(depth);
    for level in 0..depth {
        let base = level * SIBLINGS_PER_LEVEL * 32;
        let end = base + SIBLINGS_PER_LEVEL * 32;
        if end > input.sorted_siblings_flat.len() {
            return Err(format!(
                "Insufficient sibling data at level {}: need {} bytes, have {}",
                level,
                end,
                input.sorted_siblings_flat.len()
            ));
        }
        let mut sibs = [[0u8; 32]; SIBLINGS_PER_LEVEL];
        for s in 0..SIBLINGS_PER_LEVEL {
            let start = base + s * 32;
            sibs[s] = input.sorted_siblings_flat[start..start + 32]
                .try_into()
                .map_err(|_| format!("Failed to parse sibling at level {} idx {}", level, s))?;
        }
        zk_merkle_siblings.push(sibs);
    }

    let private = PrivateCircuitInputs {
        secret: Secret::from(secret_digest),
        transfer_count: input.transfer_count,
        unspendable_account: unspendable_bytes,
        parent_hash: vec_to_digest(&input.parent_hash, "parent_hash")?,
        state_root: vec_to_digest(&input.state_root, "state_root")?,
        extrinsics_root: vec_to_digest(&input.extrinsics_root, "extrinsics_root")?,
        digest: digest_padded,
        input_amount: input.input_amount,
        zk_tree_root: vec_to_32(&input.zk_tree_root, "zk_tree_root")?,
        zk_merkle_siblings,
        zk_merkle_positions: input.positions.clone(),
    };

    let public = PublicCircuitInputs {
        asset_id: input.asset_id,
        output_amount_1: input.output_amount_1,
        output_amount_2: input.output_amount_2,
        volume_fee_bps: input.volume_fee_bps,
        nullifier: nullifier_bytes,
        exit_account_1: vec_to_digest(&input.exit_account_1, "exit_account_1")?,
        exit_account_2: vec_to_digest(&input.exit_account_2, "exit_account_2")?,
        block_hash: vec_to_digest(&input.block_hash, "block_hash")?,
        block_number: input.block_number,
    };

    let circuit_inputs = CircuitInputs { public, private };

    let prover = qp_wormhole_prover::build_fresh();

    let prover_with_inputs = prover
        .commit(&circuit_inputs)
        .map_err(|e| format!("Failed to commit inputs: {}", e))?;

    let proof = prover_with_inputs
        .prove()
        .map_err(|e| format!("Proof generation failed: {}", e))?;

    Ok(ProofOutput {
        proof_bytes: proof.to_bytes(),
        nullifier: nullifier_bytes.to_vec(),
    })
}

pub fn aggregate_proofs(proof_bytes_list: Vec<Vec<u8>>, bins_dir: String) -> Result<Vec<u8>, String> {
    use plonky2::plonk::proof::ProofWithPublicInputs;
    use qp_wormhole_aggregator::private_batch::prover::PrivateBatchProver;
    use qp_zk_circuits_common::circuit::{C, D, F};

    let bins_path = versioned_bins_dir(Path::new(&bins_dir));

    let leaf_prover = qp_wormhole_prover::build_fresh();
    let common_data = &leaf_prover.circuit_data.common;

    let leaf_proofs: Vec<_> = proof_bytes_list
        .iter()
        .enumerate()
        .map(|(i, bytes)| {
            ProofWithPublicInputs::<F, C, D>::from_bytes(bytes.clone(), common_data)
                .map_err(|e| format!("Failed to deserialize proof {}: {:?}", i, e))
        })
        .collect::<Result<_, _>>()?;

    let prover = PrivateBatchProver::new_from_binaries_dir(&bins_path)
        .map_err(|e| format!("Failed to create private-batch prover: {}", e))?;

    let aggregated = prover
        .aggregate(leaf_proofs)
        .map_err(|e| format!("Aggregation failed: {}", e))?;

    Ok(aggregated.to_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versioned_bins_dir_appends_version() {
        let base = Path::new("/tmp/circuits");
        let result = versioned_bins_dir(base);
        assert_eq!(result, PathBuf::from(format!("/tmp/circuits/v{}", ZK_CIRCUITS_VERSION)));
    }

    #[test]
    fn zk_circuits_version_matches_const() {
        assert_eq!(zk_circuits_version(), ZK_CIRCUITS_VERSION);
    }

    #[test]
    fn cleanup_removes_legacy_files() {
        let tmp = tempfile::tempdir().unwrap();
        let base = tmp.path();
        for name in LEGACY_FILES {
            std::fs::write(base.join(name), b"x").unwrap();
        }
        cleanup_stale_circuit_dirs(base);
        for name in LEGACY_FILES {
            assert!(!base.join(name).exists(), "{} should have been removed", name);
        }
    }

    #[test]
    fn cleanup_removes_old_version_dirs() {
        let tmp = tempfile::tempdir().unwrap();
        let base = tmp.path();
        std::fs::create_dir(base.join("v1.0.0")).unwrap();
        std::fs::create_dir(base.join("v3.9.0")).unwrap();
        let current = format!("v{}", ZK_CIRCUITS_VERSION);
        std::fs::create_dir(base.join(&current)).unwrap();

        cleanup_stale_circuit_dirs(base);

        assert!(!base.join("v1.0.0").exists());
        assert!(!base.join("v3.9.0").exists());
        assert!(base.join(&current).exists(), "current version dir must survive");
    }

    #[test]
    fn cleanup_ignores_non_version_entries() {
        let tmp = tempfile::tempdir().unwrap();
        let base = tmp.path();
        std::fs::create_dir(base.join("other_dir")).unwrap();
        std::fs::write(base.join("notes.txt"), b"keep").unwrap();

        cleanup_stale_circuit_dirs(base);

        assert!(base.join("other_dir").exists());
        assert!(base.join("notes.txt").exists());
    }

    #[test]
    fn cleanup_on_empty_dir_is_noop() {
        let tmp = tempfile::tempdir().unwrap();
        cleanup_stale_circuit_dirs(tmp.path());
    }

    #[test]
    fn all_required_files_exist_true_when_complete() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path();
        for name in &["common.bin", "verifier.bin", "dummy_proof.bin",
                      "private_batch_common.bin", "private_batch_verifier.bin", "config.json"] {
            std::fs::write(dir.join(name), b"x").unwrap();
        }
        assert!(all_required_files_exist(dir));
    }

    #[test]
    fn all_required_files_exist_false_when_missing() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path();
        std::fs::write(dir.join("common.bin"), b"x").unwrap();
        assert!(!all_required_files_exist(dir));
    }

    #[test]
    fn compute_address_hash_hex_deterministic() {
        let addr = vec![42u8; 32];
        let h1 = compute_address_hash_hex(addr.clone()).unwrap();
        let h2 = compute_address_hash_hex(addr).unwrap();
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64);
    }

    #[test]
    fn compute_address_hash_hex_rejects_wrong_length() {
        assert!(compute_address_hash_hex(vec![0u8; 31]).is_err());
        assert!(compute_address_hash_hex(vec![0u8; 33]).is_err());
    }

    #[test]
    fn output_amount_with_10bps_fee() {
        let out = wormhole_compute_output_amount(10_000, 10).unwrap();
        assert_eq!(out, 9990);
    }

    #[test]
    fn output_amount_zero_fee() {
        let out = wormhole_compute_output_amount(10_000, 0).unwrap();
        assert_eq!(out, 10_000);
    }

    #[test]
    fn output_amount_full_fee() {
        let out = wormhole_compute_output_amount(10_000, 10_000).unwrap();
        assert_eq!(out, 0);
    }

    #[test]
    fn output_amount_rejects_excessive_fee() {
        assert!(wormhole_compute_output_amount(1, 10_001).is_err());
    }

    #[test]
    fn decode_leaf_amount_valid() {
        let mut data = vec![0u8; 60];
        let amount: u128 = 500 * SCALE_DOWN_FACTOR;
        data[44..60].copy_from_slice(&amount.to_le_bytes());
        assert_eq!(decode_leaf_amount(data).unwrap(), 500);
    }

    #[test]
    fn decode_leaf_amount_too_short() {
        assert!(decode_leaf_amount(vec![0u8; 59]).is_err());
    }

    #[test]
    fn decode_leaf_transfer_count_valid() {
        let mut data = vec![0u8; 40];
        data[32..40].copy_from_slice(&77u64.to_le_bytes());
        assert_eq!(decode_leaf_transfer_count(data).unwrap(), 77);
    }

    #[test]
    fn decode_leaf_transfer_count_too_short() {
        assert!(decode_leaf_transfer_count(vec![0u8; 39]).is_err());
    }

    #[test]
    fn decode_leaf_to_account_valid() {
        let mut data = vec![0u8; 64];
        data[0..32].copy_from_slice(&[0xAB; 32]);
        assert_eq!(decode_leaf_to_account(data).unwrap(), vec![0xAB; 32]);
    }

    #[test]
    fn decode_leaf_to_account_too_short() {
        assert!(decode_leaf_to_account(vec![0u8; 31]).is_err());
    }

    #[test]
    fn compute_nullifier_deterministic() {
        let secret = vec![1u8; 32];
        let n1 = compute_nullifier(secret.clone(), 0).unwrap();
        let n2 = compute_nullifier(secret.clone(), 0).unwrap();
        assert_eq!(n1, n2);
        let n3 = compute_nullifier(secret, 1).unwrap();
        assert_ne!(n1, n3);
    }

    #[test]
    fn compute_nullifier_rejects_bad_length() {
        assert!(compute_nullifier(vec![0u8; 16], 0).is_err());
    }

    #[test]
    fn compute_wormhole_address_deterministic() {
        let secret = vec![7u8; 32];
        let a1 = compute_wormhole_address(secret.clone()).unwrap();
        let a2 = compute_wormhole_address(secret).unwrap();
        assert_eq!(a1, a2);
        assert_eq!(a1.len(), 32);
    }

    #[test]
    fn compute_wormhole_address_rejects_bad_length() {
        assert!(compute_wormhole_address(vec![0u8; 10]).is_err());
    }
}
