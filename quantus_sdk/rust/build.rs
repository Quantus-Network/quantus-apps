//! Build script for quantus_sdk Rust library.
//!
//! Generates circuit binaries at build time to the assets/circuits/ directory.
//! This ensures the binaries are always consistent with the circuit crate version.

use std::env;
use std::path::Path;
use std::time::Instant;

fn main() {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");

    // Output to the assets/circuits directory (relative to quantus_sdk package root)
    let output_dir = Path::new(&manifest_dir).join("../assets/circuits");

    let num_leaf_proofs: usize = env::var("QP_NUM_LEAF_PROOFS")
        .unwrap_or_else(|_| "16".to_string())
        .parse()
        .expect("QP_NUM_LEAF_PROOFS must be a valid usize");


    println!(
        "cargo:warning=[quantus_sdk] Generating ZK circuit binaries (num_leaf_proofs={})...",
        num_leaf_proofs
    );

    let start = Instant::now();

    // Create the output directory if it doesn't exist
    std::fs::create_dir_all(&output_dir).expect("Failed to create assets/circuits directory");

    // Generate all circuit binaries (leaf + aggregated, WITH prover)
    qp_wormhole_circuit_builder::generate_all_circuit_binaries(
        &output_dir,
        true, // include_prover = true (SDK needs prover for proof generation)
        num_leaf_proofs,
        None, // num_layer0_proofs - use default
    )
    .expect("Failed to generate circuit binaries");

    let elapsed = start.elapsed();
    println!(
        "cargo:warning=[quantus_sdk] ZK circuit binaries generated in {:.2}s",
        elapsed.as_secs_f64()
    );
}
