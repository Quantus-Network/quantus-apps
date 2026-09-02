//! FIPS 204 ML-DSA context strings for domain separation.
//!
//! `sign` / `verify` hash the context into the signature, so a signature made
//! under one string will not verify under another, even over the same message
//! and key. These must match the chain's
//! `primitives/dilithium-crypto/src/signing_context.rs`.
//!
//! Each string is at most 255 bytes, as required by FIPS 204.

/// On-chain extrinsic signatures.
pub const EXTRINSIC: &[u8] = b"QUANTUS_EXTRINSIC";

/// First spec that verifies extrinsics under [`EXTRINSIC`]. Earlier specs use the empty context.
pub const EXTRINSIC_MIN_SPEC: u32 = 148;

const _: () = assert!(EXTRINSIC.len() <= 255);

pub fn context_for_spec(spec_version: u32) -> Option<&'static [u8]> {
    (spec_version >= EXTRINSIC_MIN_SPEC).then_some(EXTRINSIC)
}
