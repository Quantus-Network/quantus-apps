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

/// Lightweight variant that only generates leaf circuit binaries (prover.bin,
/// common.bin, verifier.bin, dummy_proof.bin). Skips the heavy aggregation
/// circuit generation entirely. Use with `aggregate_proofs_fresh` which builds
/// the aggregation circuit in memory at proving time.
pub fn ensure_leaf_circuit_binaries(bins_dir: String) -> Result<(), String> {
    let dir = Path::new(&bins_dir);
    std::fs::create_dir_all(dir)
        .map_err(|e| format!("Failed to create bins directory {}: {}", bins_dir, e))?;

    if leaf_files_exist(dir) {
        eprintln!("[ensure_leaf] all leaf files already exist at {}", bins_dir);
        return Ok(());
    }

    eprintln!("[ensure_leaf] generating leaf circuit binaries at {}...", bins_dir);
    let t0 = std::time::Instant::now();
    qp_wormhole_circuit_builder::generate_circuit_binaries(dir, true)
        .map_err(|e| format!("Leaf circuit binary generation failed: {}", e))?;
    eprintln!("[ensure_leaf] DONE (+{}ms)", t0.elapsed().as_millis());

    Ok(())
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

fn leaf_files_exist(dir: &Path) -> bool {
    const REQUIRED: &[&str] = &["prover.bin", "verifier.bin", "common.bin", "dummy_proof.bin"];
    REQUIRED.iter().all(|f| dir.join(f).exists())
}

pub fn generate_proof(
    input: ProofInput,
    prover_bin_path: String,
    common_bin_path: String,
) -> Result<ProofOutput, String> {
    let t0 = std::time::Instant::now();
    let leaf_input_size = input.sorted_siblings_flat.len() + input.positions.len() + input.digest.len();
    log_mem("leaf_entry");
    eprintln!("[leaf] transfer_count={} input_size={}B", input.transfer_count, leaf_input_size);

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

    log_mem("before PrivateCircuitInputs");

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
    log_mem("after PrivateCircuitInputs");

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

    let t_load = std::time::Instant::now();
    let prover =
        WormholeProver::new_from_files(Path::new(&prover_bin_path), Path::new(&common_bin_path))
            .map_err(|e| format!("Failed to load prover: {}", e))?;
    eprintln!("[leaf] prover loaded in {}ms", t_load.elapsed().as_millis());
    log_mem("leaf_post_load");

    let t_commit = std::time::Instant::now();
    let prover_with_inputs = prover
        .commit(&circuit_inputs)
        .map_err(|e| format!("Failed to commit inputs: {}", e))?;
    eprintln!("[leaf] commit in {}ms", t_commit.elapsed().as_millis());
    log_mem("leaf_post_commit");

    let t_prove = std::time::Instant::now();
    let proof = prover_with_inputs
        .prove()
        .map_err(|e| format!("Proof generation failed: {}", e))?;
    eprintln!("[leaf] prove in {}ms", t_prove.elapsed().as_millis());
    log_mem("leaf_post_prove");

    let proof_bytes = proof.to_bytes();
    drop(proof);
    log_mem("leaf_post_to_bytes");
    eprintln!(
        "[leaf] total {}ms, output {} bytes",
        t0.elapsed().as_millis(),
        proof_bytes.len()
    );

    Ok(ProofOutput {
        proof_bytes,
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
    let t0 = std::time::Instant::now();
    eprintln!("[agg] start, num_proofs={}, bins_dir={}", proof_bytes_list.len(), bins_dir);
    log_mem("agg_start");

    let mut aggregator = Layer0Aggregator::new(bins_path)
        .map_err(|e| format!("Failed to load aggregator: {}", e))?;
    eprintln!("[agg] Layer0Aggregator::new done (+{}ms)", t0.elapsed().as_millis());
    log_mem("agg_after_new");

    let common_data = aggregator
        .load_common_data(CircuitType::Leaf)
        .map_err(|e| format!("Failed to load leaf circuit data: {}", e))?;
    eprintln!("[agg] common_data loaded (+{}ms)", t0.elapsed().as_millis());
    log_mem("agg_after_load_common");

    for (i, proof_bytes) in proof_bytes_list.iter().enumerate() {
        let proof = ProofWithPublicInputs::<F, C, D>::from_bytes(proof_bytes.clone(), &common_data)
            .map_err(|e| format!("Failed to deserialize proof {}: {:?}", i, e))?;
        aggregator
            .push_proof(proof)
            .map_err(|e| format!("Failed to push proof {}: {}", i, e))?;
        if i == 0 || i + 1 == proof_bytes_list.len() {
            log_mem(&format!("agg_after_push_{}", i + 1));
        }
    }
    eprintln!("[agg] all {} proofs pushed (+{}ms)", proof_bytes_list.len(), t0.elapsed().as_millis());
    log_mem("agg_before_aggregate_call");

    let aggregated = aggregator
        .aggregate()
        .map_err(|e| format!("Aggregation failed: {}", e))?;
    eprintln!("[agg] aggregate() returned (+{}ms)", t0.elapsed().as_millis());
    log_mem("agg_after_aggregate_call");

    let bytes = aggregated.to_bytes();
    drop(aggregated);
    log_mem("agg_after_to_bytes");
    eprintln!("[agg] DONE, output {} bytes (+{}ms)", bytes.len(), t0.elapsed().as_millis());
    Ok(bytes)
}

// Layout must match Apple's <mach/task_info.h> task_vm_info exactly.
// Critical types: mach_vm_size_t = u64, integer_t = i32, mach_vm_address_t = u64.
// Previous version had region_count: u64 + page_size: u32 which shifted every
// subsequent field by 4-8 bytes and made phys_footprint actually read the
// `min_address` field, returning a phantom ~4 GB value on ARM64 iOS.
// We stop at phys_footprint (TASK_VM_INFO_REV1 = 38 u32s = 152 bytes).
#[cfg(target_vendor = "apple")]
#[repr(C)]
struct TaskVmInfoRev1 {
    virtual_size: u64,
    region_count: i32,
    page_size: i32,
    resident_size: u64,
    resident_size_peak: u64,
    device: u64,
    device_peak: u64,
    internal: u64,
    internal_peak: u64,
    external: u64,
    external_peak: u64,
    reusable: u64,
    reusable_peak: u64,
    purgeable_volatile_pmap: u64,
    purgeable_volatile_resident: u64,
    purgeable_volatile_virtual: u64,
    compressed: u64,
    compressed_peak: u64,
    compressed_lifetime: u64,
    phys_footprint: u64,
}

#[cfg(target_vendor = "apple")]
const _: () = assert!(std::mem::size_of::<TaskVmInfoRev1>() == 152);

#[cfg(target_vendor = "apple")]
const TASK_VM_INFO: u32 = 22;

#[cfg(target_vendor = "apple")]
unsafe fn read_task_vm_info() -> Option<TaskVmInfoRev1> {
    use std::mem::MaybeUninit;
    extern "C" {
        fn mach_task_self() -> u32;
        fn task_info(task: u32, flavor: u32, info: *mut i32, count: *mut u32) -> i32;
    }
    let mut info: MaybeUninit<TaskVmInfoRev1> = MaybeUninit::zeroed();
    let mut count: u32 =
        (std::mem::size_of::<TaskVmInfoRev1>() / std::mem::size_of::<u32>()) as u32;
    let kr = task_info(
        mach_task_self(),
        TASK_VM_INFO,
        info.as_mut_ptr() as *mut i32,
        &mut count,
    );
    if kr == 0 {
        Some(info.assume_init())
    } else {
        None
    }
}

/// Returns (phys_footprint_bytes, virtual_bytes) for the current process.
fn process_memory() -> (u64, u64) {
    #[cfg(target_vendor = "apple")]
    unsafe {
        if let Some(info) = read_task_vm_info() {
            return (info.phys_footprint, info.virtual_size);
        }
        (0, 0)
    }
    #[cfg(not(target_vendor = "apple"))]
    {
        (0, 0)
    }
}

fn log_mem(tag: &str) {
    #[cfg(target_vendor = "apple")]
    unsafe {
        if let Some(info) = read_task_vm_info() {
            eprintln!(
                "[mem] {tag} phys={}MB resident={}MB compressed={}MB internal={}MB external={}MB virt={}MB",
                info.phys_footprint / (1024 * 1024),
                info.resident_size / (1024 * 1024),
                info.compressed / (1024 * 1024),
                info.internal / (1024 * 1024),
                info.external / (1024 * 1024),
                info.virtual_size / (1024 * 1024),
            );
            return;
        }
    }
    eprintln!("[mem] {tag} (unavailable on this platform)");
}

/// Dump every field of task_vm_info for deep debugging. Call sparingly.
pub fn log_mem_detailed(tag: String) -> Result<(), String> {
    #[cfg(target_vendor = "apple")]
    unsafe {
        let Some(info) = read_task_vm_info() else {
            eprintln!("[mem_detailed] {tag} task_info failed");
            return Ok(());
        };
        eprintln!("[mem_detailed] {tag}");
        eprintln!("  virtual_size               = {} MB", info.virtual_size / (1024 * 1024));
        eprintln!("  region_count               = {}", info.region_count);
        eprintln!("  page_size                  = {}", info.page_size);
        eprintln!("  resident_size              = {} MB", info.resident_size / (1024 * 1024));
        eprintln!("  resident_size_peak         = {} MB", info.resident_size_peak / (1024 * 1024));
        eprintln!("  internal                   = {} MB", info.internal / (1024 * 1024));
        eprintln!("  internal_peak              = {} MB", info.internal_peak / (1024 * 1024));
        eprintln!("  external                   = {} MB", info.external / (1024 * 1024));
        eprintln!("  external_peak              = {} MB", info.external_peak / (1024 * 1024));
        eprintln!("  reusable                   = {} MB", info.reusable / (1024 * 1024));
        eprintln!("  reusable_peak              = {} MB", info.reusable_peak / (1024 * 1024));
        eprintln!("  purgeable_volatile_pmap    = {} MB", info.purgeable_volatile_pmap / (1024 * 1024));
        eprintln!("  purgeable_volatile_resident= {} MB", info.purgeable_volatile_resident / (1024 * 1024));
        eprintln!("  compressed                 = {} MB", info.compressed / (1024 * 1024));
        eprintln!("  compressed_peak            = {} MB", info.compressed_peak / (1024 * 1024));
        eprintln!("  compressed_lifetime        = {} MB", info.compressed_lifetime / (1024 * 1024));
        eprintln!("  phys_footprint             = {} MB", info.phys_footprint / (1024 * 1024));
    }
    #[cfg(not(target_vendor = "apple"))]
    {
        eprintln!("[mem_detailed] {tag} (only available on Apple platforms)");
    }
    Ok(())
}

/// Returns (phys_footprint_bytes, virtual_bytes). Useful for Dart-side polling.
#[flutter_rust_bridge::frb(sync)]
pub fn get_process_memory() -> (u64, u64) {
    process_memory()
}

/// Returns (phys_footprint, resident_size, compressed). Dart-side memory probe.
#[flutter_rust_bridge::frb(sync)]
pub fn get_process_memory_detailed() -> (u64, u64, u64) {
    #[cfg(target_vendor = "apple")]
    unsafe {
        if let Some(info) = read_task_vm_info() {
            return (info.phys_footprint, info.resident_size, info.compressed);
        }
    }
    (0, 0, 0)
}

/// Dart-side hook to dump every memory field.
#[flutter_rust_bridge::frb(sync)]
pub fn log_memory_snapshot(tag: String) {
    let _ = log_mem_detailed(tag);
}

/// Force the system allocator (Apple libmalloc) to return freed pages to the OS.
/// On other platforms this is a no-op.
/// Apple's malloc keeps freed memory in per-zone caches by default; after a heavy
/// allocation phase like ZK proving this can leave 100s of MB of dirty pages.
/// We iterate every registered zone — passing `null` only reaches the default
/// zone, which is NOT where Rust's allocator lives, so calling on null released
/// 0 bytes in practice.
pub fn release_memory() -> Result<(), String> {
    log_mem("release_memory_before");
    #[cfg(target_vendor = "apple")]
    unsafe {
        extern "C" {
            fn malloc_get_all_zones(
                task: u32,
                reader: *mut std::ffi::c_void,
                addresses: *mut *mut *mut std::ffi::c_void,
                count: *mut u32,
            ) -> i32;
            fn malloc_zone_pressure_relief(
                zone: *mut std::ffi::c_void,
                goal: usize,
            ) -> usize;
        }
        let mut zones: *mut *mut std::ffi::c_void = std::ptr::null_mut();
        let mut count: u32 = 0;
        let kr = malloc_get_all_zones(0, std::ptr::null_mut(), &mut zones, &mut count);
        let mut total: usize = 0;
        if kr == 0 && !zones.is_null() {
            for i in 0..count as isize {
                let zone = *zones.offset(i);
                if zone.is_null() {
                    continue;
                }
                total = total.saturating_add(malloc_zone_pressure_relief(zone, 0));
            }
        }
        let default_released = malloc_zone_pressure_relief(std::ptr::null_mut(), 0);
        eprintln!(
            "[release_memory] released {} bytes ({} MB) across {} zones (+{} from default)",
            total,
            total / (1024 * 1024),
            count,
            default_released
        );
    }
    log_mem("release_memory_after");
    Ok(())
}

/// Limit rayon parallelism to reduce peak memory during proving.
/// Plonky2 multiplies its per-thread FFT buffers by the rayon pool size, so
/// fewer threads = lower peak memory (at the cost of wall-clock time).
/// Idempotent / safe to call repeatedly; only the first call wins.
pub fn set_proving_thread_count(num_threads: u32) -> Result<(), String> {
    let n = num_threads.max(1) as usize;
    eprintln!("[rayon] requesting global pool size = {}", n);
    match rayon::ThreadPoolBuilder::new().num_threads(n).build_global() {
        Ok(()) => {
            eprintln!("[rayon] global pool initialized with {} threads", n);
            Ok(())
        }
        Err(e) => {
            eprintln!("[rayon] global pool already initialized: {}", e);
            Ok(())
        }
    }
}

pub fn aggregate_proofs_fresh(proof_bytes_list: Vec<Vec<u8>>, bins_dir: String) -> Result<Vec<u8>, String> {
    use plonky2::plonk::circuit_data::CommonCircuitData;
    use plonky2::plonk::proof::ProofWithPublicInputs;
    use plonky2::util::serialization::DefaultGateSerializer;
    use qp_wormhole_aggregator::layer0::prover::Layer0AggregationProver;
    use qp_wormhole_aggregator::dummy_proof::load_dummy_proof;
    use qp_zk_circuits_common::circuit::{wormhole_aggregator_circuit_config, C, D, F};

    let t0 = std::time::Instant::now();
    eprintln!("[agg_fresh] start, num_proofs={}, bins_dir={}", proof_bytes_list.len(), bins_dir);
    log_mem("start");

    let bins_path = Path::new(&bins_dir);
    let gate_serializer = DefaultGateSerializer;

    eprintln!("[agg_fresh] reading common.bin (+{}ms)", t0.elapsed().as_millis());
    let leaf_common_bytes = std::fs::read(bins_path.join("common.bin"))
        .map_err(|e| format!("Failed to read common.bin: {}", e))?;
    eprintln!("[agg_fresh] common.bin read, {} bytes", leaf_common_bytes.len());
    let leaf_common = CommonCircuitData::<F, D>::from_bytes(leaf_common_bytes, &gate_serializer)
        .map_err(|e| format!("Failed to deserialize common.bin: {}", e))?;
    eprintln!("[agg_fresh] common.bin deserialized (+{}ms)", t0.elapsed().as_millis());

    let leaf_verifier_bytes = std::fs::read(bins_path.join("verifier.bin"))
        .map_err(|e| format!("Failed to read verifier.bin: {}", e))?;
    eprintln!("[agg_fresh] verifier.bin read, {} bytes", leaf_verifier_bytes.len());
    let leaf_verifier_only = plonky2::plonk::circuit_data::VerifierOnlyCircuitData::<C, D>::from_bytes(leaf_verifier_bytes)
        .map_err(|e| format!("Failed to deserialize verifier.bin: {}", e))?;

    let dummy_proof_bytes = std::fs::read(bins_path.join("dummy_proof.bin"))
        .map_err(|e| format!("Failed to read dummy_proof.bin: {}", e))?;
    eprintln!("[agg_fresh] dummy_proof.bin read, {} bytes", dummy_proof_bytes.len());
    let dummy_proof = load_dummy_proof(dummy_proof_bytes, &leaf_common)
        .map_err(|e| format!("Failed to deserialize dummy proof: {}", e))?;
    eprintln!("[agg_fresh] leaf artifacts loaded (+{}ms)", t0.elapsed().as_millis());

    eprintln!("[agg_fresh] deserializing {} input proofs", proof_bytes_list.len());
    let mut proofs: Vec<ProofWithPublicInputs<F, C, D>> = Vec::with_capacity(proof_bytes_list.len());
    for (i, bytes) in proof_bytes_list.iter().enumerate() {
        let p = ProofWithPublicInputs::<F, C, D>::from_bytes(bytes.clone(), &leaf_common)
            .map_err(|e| format!("Failed to deserialize proof {}: {:?}", i, e))?;
        proofs.push(p);
        eprintln!("[agg_fresh]   deserialized proof {}/{} (input {} bytes)", i + 1, proof_bytes_list.len(), bytes.len());
    }
    eprintln!("[agg_fresh] all input proofs deserialized (+{}ms)", t0.elapsed().as_millis());
    log_mem("after_deserialize");

    eprintln!("[agg_fresh] BUILDING aggregation circuit in memory (this is the heavy step)...");
    let prover = Layer0AggregationProver::new(
        wormhole_aggregator_circuit_config(),
        leaf_common,
        &leaf_verifier_only,
        DEFAULT_NUM_LEAF_PROOFS,
        dummy_proof,
    );
    eprintln!("[agg_fresh] aggregation circuit BUILT (+{}ms)", t0.elapsed().as_millis());
    log_mem("after_circuit_build");

    eprintln!("[agg_fresh] committing proofs to witness...");
    let prover = prover.commit(proofs)
        .map_err(|e| format!("Failed to commit proofs: {}", e))?;
    eprintln!("[agg_fresh] proofs committed (+{}ms)", t0.elapsed().as_millis());
    log_mem("after_commit");

    eprintln!("[agg_fresh] PROVING aggregation...");
    log_mem("before_prove");
    let aggregated = prover.prove()
        .map_err(|e| format!("Aggregation proving failed: {}", e))?;
    eprintln!("[agg_fresh] PROVED (+{}ms)", t0.elapsed().as_millis());
    log_mem("after_prove");

    let bytes = aggregated.to_bytes();
    eprintln!("[agg_fresh] DONE, output {} bytes (+{}ms)", bytes.len(), t0.elapsed().as_millis());
    Ok(bytes)
}
