use qp_wormhole_circuit::{
    inputs::{CircuitInputs, PrivateCircuitInputs},
    nullifier::Nullifier,
};
use qp_wormhole_inputs::PublicCircuitInputs;
use qp_wormhole_prover::WormholeProver;
use qp_zk_circuits_common::{
    utils::{digest_to_bytes, BytesDigest},
    zk_merkle::{hash_node_presorted, SIBLINGS_PER_LEVEL},
};
use std::path::Path;

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
pub const MAX_PROOFS_PER_BATCH: u32 = 16;
pub const DEFAULT_NUM_LEAF_PROOFS: usize = 16;

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
pub fn wormhole_compute_output_amount(input_amount: u32, fee_bps: u32) -> u32 {
    ((input_amount as u64) * (10000 - fee_bps as u64) / 10000) as u32
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
    Ok((raw_amount / SCALE_DOWN_FACTOR) as u32)
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

        current_hash = hash_node_presorted(&all_four);
    }

    Ok(MerkleProcessed {
        sorted_siblings_flat: sorted_out,
        positions: positions_out,
    })
}

pub fn ensure_circuit_binaries(bins_dir: String) -> Result<String, String> {
    let dir = Path::new(&bins_dir);
    std::fs::create_dir_all(dir)
        .map_err(|e| format!("Failed to create bins directory {}: {}", bins_dir, e))?;

    let config_path = dir.join("config.json");
    if config_path.exists() && all_required_files_exist(dir) {
        let config_str = std::fs::read_to_string(&config_path)
            .map_err(|e| format!("Failed to read config.json: {}", e))?;
        return Ok(config_str);
    }

    qp_wormhole_circuit_builder::generate_all_circuit_binaries(
        dir,
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
    const REQUIRED: &[&str] = &[
        "prover.bin",
        "verifier.bin",
        "common.bin",
        "aggregated_prover.bin",
        "aggregated_verifier.bin",
        "aggregated_common.bin",
        "dummy_proof.bin",
        "config.json",
    ];
    REQUIRED.iter().all(|f| dir.join(f).exists())
}

pub fn generate_proof(
    input: ProofInput,
    prover_bin_path: String,
    common_bin_path: String,
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
        secret: secret_digest,
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
        output_amount_2: 0,
        volume_fee_bps: input.volume_fee_bps,
        nullifier: nullifier_bytes,
        exit_account_1: vec_to_digest(&input.exit_account_1, "exit_account_1")?,
        exit_account_2: vec_to_digest(&[0u8; 32], "exit_account_2")?,
        block_hash: vec_to_digest(&input.block_hash, "block_hash")?,
        block_number: input.block_number,
    };

    let circuit_inputs = CircuitInputs { public, private };

    let prover =
        WormholeProver::new_from_files(Path::new(&prover_bin_path), Path::new(&common_bin_path))
            .map_err(|e| format!("Failed to load prover: {}", e))?;

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
    use qp_wormhole_aggregator::{
        aggregator::{AggregationBackend, CircuitType, Layer0Aggregator},
    };
    use qp_zk_circuits_common::circuit::{C, D, F};

    let bins_path = Path::new(&bins_dir);

    let mut aggregator = Layer0Aggregator::new(bins_path)
        .map_err(|e| format!("Failed to load aggregator: {}", e))?;

    let common_data = aggregator
        .load_common_data(CircuitType::Leaf)
        .map_err(|e| format!("Failed to load leaf circuit data: {}", e))?;

    for (i, proof_bytes) in proof_bytes_list.iter().enumerate() {
        let proof = ProofWithPublicInputs::<F, C, D>::from_bytes(proof_bytes.clone(), &common_data)
            .map_err(|e| format!("Failed to deserialize proof {}: {:?}", i, e))?;
        aggregator
            .push_proof(proof)
            .map_err(|e| format!("Failed to push proof {}: {}", i, e))?;
    }

    let aggregated = aggregator
        .aggregate()
        .map_err(|e| format!("Aggregation failed: {}", e))?;

    Ok(aggregated.to_bytes())
}
