//! Airdrop snapshot matching. Given the claim-server snapshot address list,
//! derive every historical address format from the wallet's keys locally and
//! return which snapshot rows belong to this wallet. Nothing here talks to a
//! server; secrets never leave the process.
//!
//! Testnet address history:
//! - early Resonance (poseidon-resonance 0.8.0): legacy plonky2 Poseidon,
//!   8-byte limbs zero-padded to 73 felts
//! - mid Resonance (qp-poseidon 0.9.1): legacy plonky2 Poseidon, 4-byte limbs
//!   zero-padded to 188 felts
//! - Resonance / early Schrödinger (qp-poseidon 0.9.5): different permutation
//!   constants (ChaCha8, seed 0x189189189189189) AND a different sponge
//!   (rate 4, pad10 + domain block). Handled by the real 0.9.5 crate.
//! - late Schrödinger / Dirac (1.0.x–1.1.x): current permutation, rate 4, pad10
//! - late Planck / current (1.2.x+): current permutation, rate 8, pad10

use qp_ownership_circuit::{BytesDigest, CircuitInputs, Secret};
use qp_poseidon_core::{
    serialization::digest_to_bytes, Goldilocks, Poseidon2, POSEIDON2_OUTPUT, SPONGE_WIDTH,
};
use qp_poseidon_core_v09 as v09;
use qp_rusty_crystals_dilithium::ml_dsa_87;
use qp_rusty_crystals_hdwallet::{
    generate_wormhole_from_seed, mnemonic_to_seed, SensitiveBytes64, QUANTUS_WORMHOLE_CHAIN_ID,
};
use std::collections::HashMap;

const RATE_4: usize = 4;
const WORMHOLE_SALT: &[u8] = b"wormhole";
/// Only proofs for the current wormhole scheme are accepted by the claim server.
const CLAIMABLE_WORMHOLE_SCHEME: &str = "wormhole-rate8-compact";
const HD_SCAN_INDEXES: u32 = 17;
/// Middle HD path component. The app uses 0 (external) and 1 (dedicated
/// change branch since July 2026); the CLI's wormhole multiround flow uses it
/// as a round counter (default 2 rounds), so scan several rounds beyond that.
const HD_SCAN_BRANCHES: u32 = 9;
/// FIPS 204 context for airdrop claim signatures; must match the claim server.
const CLAIM_CONTEXT: &[u8] = b"qp-airdrop-claim-v1";
/// Claim expiry horizon. The server rejects expiries more than 15 min out.
const CLAIM_TTL_SECS: i64 = 10 * 60;

// ---------------------------------------------------------------------------
// Historical Poseidon2 sponges
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum Sponge {
    /// qp-poseidon 0.9.x `hash_no_pad`: distinct permutation constants and a
    /// rate-4 pad10 sponge with a mandatory `[0,0,0,1]` block. Uses the real
    /// 0.9.5 crate; see `WormholeSchemeDef::derive`.
    V09,
    /// qp-poseidon 1.0.x–1.1.x: rate 4, pad10 only.
    Rate4Pad10,
    /// qp-poseidon 1.2.x+ (current): rate 8, pad10.
    Rate8Pad10,
}

impl Sponge {
    fn hash_felts(self, input: &[Goldilocks]) -> [u8; 32] {
        match self {
            Self::V09 => unreachable!("v09 uses its own field type; see derive()"),
            Self::Rate4Pad10 => hash_felts_rate4_pad10(input),
            Self::Rate8Pad10 => qp_poseidon_core::hash_to_bytes(input),
        }
    }

    fn rehash(self, digest: &[u8; 32]) -> [u8; 32] {
        self.hash_felts(&compact8_decode(digest))
    }
}

/// 8-byte little-endian limbs, reduced into Goldilocks.
fn compact8_decode(bytes: &[u8; 32]) -> [Goldilocks; POSEIDON2_OUTPUT] {
    qp_poseidon_core::serialization::bytes_to_digest_lossy(bytes)
}

/// v0.9.5 injective 4-bytes/felt encoding (terminator in the last word or as an extra felt).
fn injective4(bytes: &[u8]) -> Vec<Goldilocks> {
    if bytes.is_empty() {
        return Vec::new();
    }
    const N: usize = 4;
    let mut out = Vec::new();
    let num_chunks = bytes.len().div_ceil(N);
    let mut unpadded = false;
    for (i, chunk) in bytes.chunks(N).enumerate() {
        let mut word = [0u8; N];
        if i == num_chunks - 1 {
            if chunk.len() < N {
                word[chunk.len()] = 1;
            } else {
                unpadded = true;
            }
        }
        word[..chunk.len()].copy_from_slice(chunk);
        out.push(Goldilocks::from_u64(u32::from_le_bytes(word) as u64));
    }
    if unpadded {
        out.push(Goldilocks::from_u64(1));
    }
    out
}

fn hash_felts_rate4_pad10(x: &[Goldilocks]) -> [u8; 32] {
    let poseidon = Poseidon2::new();
    let mut state = [Goldilocks::ZERO; SPONGE_WIDTH];
    let mut buf = [Goldilocks::ZERO; RATE_4];
    let mut buf_len = 0usize;

    let absorb = |felt: Goldilocks,
                  state: &mut [Goldilocks; SPONGE_WIDTH],
                  buf: &mut [Goldilocks; RATE_4],
                  buf_len: &mut usize| {
        buf[*buf_len] = felt;
        *buf_len += 1;
        if *buf_len == RATE_4 {
            for i in 0..RATE_4 {
                state[i] += buf[i];
            }
            poseidon.permute_mut(state);
            *buf = [Goldilocks::ZERO; RATE_4];
            *buf_len = 0;
        }
    };

    for &felt in x {
        absorb(felt, &mut state, &mut buf, &mut buf_len);
    }
    absorb(Goldilocks::ONE, &mut state, &mut buf, &mut buf_len);
    while buf_len != 0 {
        absorb(Goldilocks::ZERO, &mut state, &mut buf, &mut buf_len);
    }

    let digest: [Goldilocks; POSEIDON2_OUTPUT] = state[..POSEIDON2_OUTPUT]
        .try_into()
        .expect("width > output");
    digest_to_bytes(&digest)
}

/// Pre-0.9.5 Resonance AccountId hash: legacy plonky2 Poseidon (unchanged in
/// today's qp-plonky2) over little-endian limbs, zero-padded to a fixed
/// preimage length. poseidon-resonance 0.8.0 used 8-byte limbs and 73 felts;
/// qp-poseidon 0.9.1 used 4-byte limbs and 188 felts.
fn hash_padded_legacy(bytes: &[u8], bytes_per_felt: usize, pad_to: usize) -> [u8; 32] {
    use plonky2::field::goldilocks_field::GoldilocksField;
    use plonky2::field::types::Field;
    use plonky2::plonk::config::{GenericHashOut, Hasher};

    let mut felts: Vec<GoldilocksField> = bytes
        .chunks(bytes_per_felt)
        .map(|chunk| {
            let mut word = [0u8; 8];
            word[..chunk.len()].copy_from_slice(chunk);
            GoldilocksField::from_noncanonical_u64(u64::from_le_bytes(word))
        })
        .collect();
    if felts.len() < pad_to {
        felts.resize(pad_to, GoldilocksField::ZERO);
    }
    plonky2::hash::poseidon::PoseidonHash::hash_no_pad(&felts)
        .to_bytes()
        .try_into()
        .expect("poseidon output is 32 bytes")
}

/// qp-poseidon 1.0.x Dilithium AccountId: injective bytes, zero-pad to 189, rate-4 pad10.
fn hash_padded_v10(bytes: &[u8]) -> [u8; 32] {
    const PAD: usize = 189;
    let mut felts = injective4(bytes);
    if felts.len() < PAD {
        felts.resize(PAD, Goldilocks::ZERO);
    }
    hash_felts_rate4_pad10(&felts)
}

// ---------------------------------------------------------------------------
// Derivation schemes
// ---------------------------------------------------------------------------

#[derive(Clone, Copy)]
enum SecretEncoding {
    Injective4,
    Compact8,
}

struct WormholeSchemeDef {
    id: &'static str,
    sponge: Sponge,
    secret_encoding: SecretEncoding,
}

const WORMHOLE_SCHEMES: &[WormholeSchemeDef] = &[
    WormholeSchemeDef {
        id: "wormhole-v09-injective",
        sponge: Sponge::V09,
        secret_encoding: SecretEncoding::Injective4,
    },
    WormholeSchemeDef {
        id: "wormhole-rate4-compact",
        sponge: Sponge::Rate4Pad10,
        secret_encoding: SecretEncoding::Compact8,
    },
    WormholeSchemeDef {
        id: "wormhole-rate8-compact",
        sponge: Sponge::Rate8Pad10,
        secret_encoding: SecretEncoding::Compact8,
    },
    WormholeSchemeDef {
        id: "wormhole-rate4-injective",
        sponge: Sponge::Rate4Pad10,
        secret_encoding: SecretEncoding::Injective4,
    },
    WormholeSchemeDef {
        id: "wormhole-rate8-injective",
        sponge: Sponge::Rate8Pad10,
        secret_encoding: SecretEncoding::Injective4,
    },
];

impl WormholeSchemeDef {
    fn derive(&self, secret: &[u8; 32]) -> [u8; 32] {
        if self.sponge == Sponge::V09 {
            let core = v09::Poseidon2Core::new();
            let mut preimage = v09::injective_bytes_to_felts(WORMHOLE_SALT);
            match self.secret_encoding {
                SecretEncoding::Injective4 => {
                    preimage.extend(v09::injective_bytes_to_felts(secret))
                }
                SecretEncoding::Compact8 => preimage.extend(v09::digest_bytes_to_felts(secret)),
            }
            let first_hash = core.hash_no_pad(preimage);
            return core.hash_no_pad(v09::digest_bytes_to_felts(&first_hash));
        }
        let mut preimage = injective4(WORMHOLE_SALT);
        match self.secret_encoding {
            SecretEncoding::Injective4 => preimage.extend(injective4(secret)),
            SecretEncoding::Compact8 => preimage.extend(compact8_decode(secret)),
        }
        let first_hash = self.sponge.hash_felts(&preimage);
        self.sponge.rehash(&first_hash)
    }
}

const DILITHIUM_SCHEMES: &[&str] = &[
    "dilithium-v08-padded",
    "dilithium-v091-padded",
    "dilithium-v09-padded",
    "dilithium-v10-padded",
    "dilithium-rate8-hash-bytes",
];

fn derive_dilithium(scheme: &str, public_key: &[u8]) -> [u8; 32] {
    match scheme {
        "dilithium-v08-padded" => hash_padded_legacy(public_key, 8, 73),
        "dilithium-v091-padded" => hash_padded_legacy(public_key, 4, 188),
        "dilithium-v09-padded" => v09::Poseidon2Core::new().hash_padded(public_key),
        "dilithium-v10-padded" => hash_padded_v10(public_key),
        "dilithium-rate8-hash-bytes" => qp_poseidon_core::hash_bytes(public_key),
        _ => unreachable!(),
    }
}

// ---------------------------------------------------------------------------
// FFI surface
// ---------------------------------------------------------------------------

/// A snapshot address this wallet can prove ownership of.
#[flutter_rust_bridge::frb(sync)]
pub struct AirdropMatch {
    /// The address exactly as it appeared in `snapshot_addresses`.
    pub address: String,
    /// "dilithium" or "wormhole".
    pub kind: String,
    /// Derivation scheme id, e.g. "dilithium-v10-padded".
    pub scheme: String,
    /// Whether the claim server currently accepts proofs for this scheme.
    pub claimable: bool,
    /// Where the key came from: "dilithium public key", an HD path, or
    /// "provided secret #N".
    pub source: String,
    /// The 32-byte wormhole secret that produced the match (needed to build
    /// the ownership proof). None for Dilithium matches.
    pub wormhole_secret: Option<Vec<u8>>,
}

/// Determine which snapshot addresses belong to this wallet.
///
/// `snapshot_addresses` are the SS58 addresses from `GET /snapshot` (or the
/// miner-rewards CSV). Dilithium matches are checked against
/// `dilithium_public_key` under every historical hash. Wormhole matches are
/// checked for HD-derived secrets (`m/44'/189189189'/0'/{0..=8}'/{0..=16}'`,
/// covering the app's external/change branches and the CLI's multiround
/// rounds) when `mnemonic` is given, plus any `extra_wormhole_secrets`
/// (32 bytes each).
pub fn find_airdrop_matches(
    snapshot_addresses: Vec<String>,
    dilithium_public_key: Option<Vec<u8>>,
    mnemonic: Option<String>,
    extra_wormhole_secrets: Vec<Vec<u8>>,
) -> Result<Vec<AirdropMatch>, String> {
    let mut by_account: HashMap<[u8; 32], String> = HashMap::new();
    for address in snapshot_addresses {
        let account: [u8; 32] = super::crypto::ss58_to_account_id(&address)?
            .try_into()
            .map_err(|_| format!("address {address} did not decode to 32 bytes"))?;
        by_account.insert(account, address);
    }

    let mut matches = Vec::new();

    if let Some(public_key) = dilithium_public_key {
        if !public_key.is_empty() {
            for scheme in DILITHIUM_SCHEMES {
                let account = derive_dilithium(scheme, &public_key);
                if let Some(address) = by_account.get(&account) {
                    matches.push(AirdropMatch {
                        address: address.clone(),
                        kind: "dilithium".into(),
                        scheme: (*scheme).into(),
                        claimable: true,
                        source: "dilithium public key".into(),
                        wormhole_secret: None,
                    });
                }
            }
        }
    }

    let mut secrets: Vec<([u8; 32], String)> = Vec::new();
    if let Some(mnemonic) = mnemonic {
        // Stretch the BIP39 seed once, then walk the HD tree per path.
        // `mnemonic_to_seed` consumes and zeroizes the mnemonic string.
        let mut seed = SensitiveBytes64::zeroed();
        mnemonic_to_seed(mnemonic, None, &mut seed)
            .map_err(|e| format!("invalid mnemonic: {e:?}"))?;
        for branch in 0..HD_SCAN_BRANCHES {
            for index in 0..HD_SCAN_INDEXES {
                let path = format!(
                    "m/44'/{}/0'/{}'/{}'",
                    QUANTUS_WORMHOLE_CHAIN_ID, branch, index
                );
                let pair = generate_wormhole_from_seed(&seed, &path)
                    .map_err(|e| format!("HD derivation failed at {path}: {e:?}"))?;
                secrets.push((*pair.secret().as_bytes(), path));
            }
        }
    }
    for (i, secret) in extra_wormhole_secrets.iter().enumerate() {
        let secret: [u8; 32] = secret
            .as_slice()
            .try_into()
            .map_err(|_| format!("wormhole secret #{i} must be 32 bytes"))?;
        secrets.push((secret, format!("provided secret #{i}")));
    }

    let mut seen: Vec<([u8; 32], &'static str)> = Vec::new();
    for (secret, source) in &secrets {
        for scheme in WORMHOLE_SCHEMES {
            let account = scheme.derive(secret);
            if let Some(address) = by_account.get(&account) {
                if seen.contains(&(account, scheme.id)) {
                    continue;
                }
                seen.push((account, scheme.id));
                matches.push(AirdropMatch {
                    address: address.clone(),
                    kind: "wormhole".into(),
                    scheme: scheme.id.into(),
                    claimable: scheme.id == CLAIMABLE_WORMHOLE_SCHEME,
                    source: source.clone(),
                    wormhole_secret: Some(secret.to_vec()),
                });
            }
        }
    }

    Ok(matches)
}

fn decode_account(label: &str, address: &str) -> Result<[u8; 32], String> {
    super::crypto::ss58_to_account_id(address)?
        .try_into()
        .map_err(|_| format!("{label} {address} did not decode to 32 bytes"))
}

fn now_unix() -> Result<i64, String> {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .map_err(|e| format!("system clock before epoch: {e}"))
}

/// The `POST /claim` body fields for a Dilithium claim.
#[derive(Debug)]
#[flutter_rust_bridge::frb(sync)]
pub struct DilithiumClaimBody {
    pub scheme: String,
    pub address: String,
    pub claim_account: String,
    pub public_key_hex: String,
    pub signature_hex: String,
    pub expiry_unix: i64,
}

/// Sign an airdrop claim for a Dilithium-era snapshot `address`, paying out to
/// `claim_account`. The wallet must be ML-DSA-87 (miner keys are). Submit the
/// result as `{"kind": "dilithium", ...fields}` within ~10 minutes.
pub fn build_airdrop_dilithium_claim(
    keypair: &super::crypto::Keypair,
    address: String,
    claim_account: String,
) -> Result<DilithiumClaimBody, String> {
    if keypair.scheme != super::crypto::DilithiumScheme::MlDsa87 {
        return Err("airdrop claims require an ML-DSA-87 keypair".into());
    }
    let address_bytes = decode_account("address", &address)?;
    let claim_bytes = decode_account("claim account", &claim_account)?;

    let scheme = DILITHIUM_SCHEMES
        .iter()
        .find(|s| derive_dilithium(s, &keypair.public_key) == address_bytes)
        .ok_or("public key does not derive this address under any known Dilithium scheme")?;

    let expiry_unix = now_unix()?.saturating_add(CLAIM_TTL_SECS);
    let mut msg = [0u8; 72];
    msg[..32].copy_from_slice(&address_bytes);
    msg[32..64].copy_from_slice(&claim_bytes);
    msg[64..].copy_from_slice(&expiry_unix.to_be_bytes());

    let secret = ml_dsa_87::SecretKey::from_bytes(&keypair.secret_key)
        .map_err(|_| "invalid ML-DSA-87 secret key")?;
    let signature = secret
        .sign(&msg, Some(CLAIM_CONTEXT), None)
        .map_err(|e| format!("ML-DSA sign failed: {e}"))?;

    Ok(DilithiumClaimBody {
        scheme: (*scheme).into(),
        address,
        claim_account,
        public_key_hex: hex::encode(&keypair.public_key),
        signature_hex: hex::encode(signature),
        expiry_unix,
    })
}

/// The `POST /claim` body fields for a wormhole claim.
#[flutter_rust_bridge::frb(sync)]
pub struct WormholeClaimBody {
    pub proof_kind: String,
    pub proof_hex: String,
}

/// Prove ownership of the wormhole address derived from `wormhole_secret`
/// (current rate-8 scheme), binding the payout to `claim_account`. Builds the
/// circuit in-process: expect tens of seconds of CPU on first call. Submit as
/// `{"kind": "wormhole", ...fields}`.
pub fn prove_airdrop_wormhole(
    wormhole_secret: Vec<u8>,
    claim_account: String,
) -> Result<WormholeClaimBody, String> {
    let secret_bytes: [u8; 32] = wormhole_secret
        .try_into()
        .map_err(|_| "wormhole secret must be 32 bytes")?;
    let secret =
        Secret::try_from(secret_bytes).map_err(|e| format!("invalid wormhole secret: {e:?}"))?;
    let claim_bytes = decode_account("claim account", &claim_account)?;
    let claim = BytesDigest::try_from(claim_bytes.as_slice())
        .map_err(|e| format!("invalid claim account: {e:?}"))?;

    let inputs = CircuitInputs::from_secret(secret, claim);
    let proof = qp_ownership_prover::build_fresh()
        .commit(&inputs)
        .map_err(|e| format!("ownership prover commit failed: {e}"))?
        .prove()
        .map_err(|e| format!("ownership proof failed: {e}"))?;

    Ok(WormholeClaimBody {
        proof_kind: "wormhole_rate8".into(),
        proof_hex: hex::encode(proof.to_bytes()),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use sp_core::crypto::{AccountId32, Ss58Codec};

    fn to_ss58(account: &[u8; 32]) -> String {
        AccountId32::new(*account)
            .to_ss58check_with_version(sp_core::crypto::Ss58AddressFormat::custom(189))
    }

    fn hex32(s: &str) -> [u8; 32] {
        hex::decode(s).unwrap().try_into().unwrap()
    }

    #[test]
    fn current_wormhole_scheme_matches_hdwallet_golden() {
        let secret = hex32("30051cfa3abd462d3bc26da2d660e90ba8af6080b7fe95d9fd3f3b37c7d9ce4b");
        let scheme = WORMHOLE_SCHEMES
            .iter()
            .find(|s| s.id == CLAIMABLE_WORMHOLE_SCHEME)
            .unwrap();
        assert_eq!(
            scheme.derive(&secret),
            hex32("6a2f0d3abe4390e0b05f6dea4ba10670676cda7c00d49526ddde59f16c85269f")
        );
    }

    /// Vectors computed with the exact crates the shipped Resonance chains
    /// pinned: poseidon-resonance 0.8.0 (rev fcb49a7, plonky2 fork rev
    /// 80a1000, per chain tag v0.0.12-resonance-alpha) and crates.io
    /// qp-poseidon 0.9.1 (per chain rev e9fc9b9). The 2592-byte inputs are
    /// ML-DSA-87 public key sized.
    #[test]
    fn pre_v095_dilithium_matches_original_crate_vectors() {
        let square_pattern: Vec<u8> = (0..2592u32).map(|i| (i * i % 251) as u8).collect();
        let vectors: &[(&str, &[u8], &str)] = &[
            (
                "dilithium-v08-padded",
                &[0u8],
                "fdf0715f178bfb2381d3804961bda8c679990d6318ff53f7a6475e1bef1982ca",
            ),
            (
                "dilithium-v08-padded",
                &[42u8; 32],
                "832c0ecb43187d773d7e54865c5148be7a2f9c9b86d8ad630196b0ff9a8037b5",
            ),
            (
                "dilithium-v08-padded",
                &[5u8; 2592],
                "9c69917b10f0228a0beed1d78ce34026b4778dc04a49a401dd5e692a51f44207",
            ),
            (
                "dilithium-v08-padded",
                &square_pattern,
                "3222344f6b35748d59d5983410b1baaba0bb680af7fecfdd7cd54de1a848977e",
            ),
            (
                "dilithium-v091-padded",
                &[0u8],
                "c4f1020767625056e669e3653f190b7763c6c398a45f1dc20db0d7ed32b14ff7",
            ),
            (
                "dilithium-v091-padded",
                &[42u8; 32],
                "19be0e79d925f42481cb5b30fb703903c866395373671728bb1594b01d850f6e",
            ),
            (
                "dilithium-v091-padded",
                &[5u8; 2592],
                "8ba4f919664c796aa811f552eaff5975570d56ed6812728944f60fe7d28d3c74",
            ),
            (
                "dilithium-v091-padded",
                &square_pattern,
                "61d1490430a295ad2d33ed55948ece058cce09b43994f35c7528f164a482a5e5",
            ),
        ];
        for (scheme, input, expected) in vectors {
            assert_eq!(
                derive_dilithium(scheme, input),
                hex32(expected),
                "{scheme} input len {}",
                input.len()
            );
        }
    }

    #[test]
    fn all_dilithium_schemes_disagree_on_same_public_key() {
        let pk = [5u8; 2592];
        let addrs: Vec<_> = DILITHIUM_SCHEMES
            .iter()
            .map(|s| derive_dilithium(s, &pk))
            .collect();
        for i in 0..addrs.len() {
            for j in (i + 1)..addrs.len() {
                assert_ne!(
                    addrs[i], addrs[j],
                    "{} and {} collide",
                    DILITHIUM_SCHEMES[i], DILITHIUM_SCHEMES[j]
                );
            }
        }
    }

    #[test]
    fn matches_v08_dilithium_address_against_snapshot() {
        let pk = vec![5u8; 2592];
        let resonance_era = derive_dilithium("dilithium-v08-padded", &pk);
        let snapshot = vec![to_ss58(&resonance_era)];

        let matches = find_airdrop_matches(snapshot.clone(), Some(pk), None, vec![]).unwrap();
        assert_eq!(matches.len(), 1);
        assert_eq!(matches[0].scheme, "dilithium-v08-padded");
        assert!(matches[0].claimable);
    }

    /// Vectors computed with qp-poseidon-core 0.9.5 (git tag v0.9.5); the
    /// `[0]` digest was also independently reproduced in review. These pin the
    /// legacy permutation constants, not just the sponge shape.
    #[test]
    fn v09_dilithium_matches_original_crate_vectors() {
        assert_eq!(
            derive_dilithium("dilithium-v09-padded", &[0u8]),
            hex32("b17b423096da9ebd57af5038b490257d9c492e64059c0ccff23f44e6293213d4")
        );
        assert_eq!(
            derive_dilithium("dilithium-v09-padded", &[5u8; 2592]),
            hex32("90d32b1ed817ec85479f70af5db84a07fb8b6c314d12d3470fc046cf873a54ac")
        );
    }

    #[test]
    fn v09_wormhole_matches_original_crate_vector() {
        let scheme = WORMHOLE_SCHEMES
            .iter()
            .find(|s| s.id == "wormhole-v09-injective")
            .unwrap();
        assert_eq!(
            scheme.derive(&[42u8; 32]),
            hex32("f4e231ede747e9ca2da9528add147ee488651a0df72b00313b0a8e6b76388fea")
        );
    }

    #[test]
    fn historical_wormhole_schemes_disagree() {
        let secret = [9u8; 32];
        let addrs: Vec<_> = WORMHOLE_SCHEMES.iter().map(|s| s.derive(&secret)).collect();
        assert!(addrs.iter().any(|a| *a != addrs[0]));
    }

    #[test]
    fn dilithium_rate8_matches_current_hash_bytes() {
        let pk = [7u8; 2592];
        assert_eq!(
            derive_dilithium("dilithium-rate8-hash-bytes", &pk),
            qp_poseidon_core::hash_bytes(&pk)
        );
    }

    #[test]
    fn matches_wormhole_secret_against_snapshot() {
        let secret = [42u8; 32];
        let current = WORMHOLE_SCHEMES
            .iter()
            .find(|s| s.id == CLAIMABLE_WORMHOLE_SCHEME)
            .unwrap()
            .derive(&secret);
        let snapshot = vec![to_ss58(&current), to_ss58(&[1u8; 32])];

        let matches =
            find_airdrop_matches(snapshot.clone(), None, None, vec![secret.to_vec()]).unwrap();
        assert_eq!(matches.len(), 1);
        assert_eq!(matches[0].address, snapshot[0]);
        assert_eq!(matches[0].kind, "wormhole");
        assert_eq!(matches[0].scheme, CLAIMABLE_WORMHOLE_SCHEME);
        assert!(matches[0].claimable);
        assert_eq!(matches[0].wormhole_secret.as_deref(), Some(&secret[..]));
    }

    #[test]
    fn matches_dilithium_public_key_against_snapshot() {
        let pk = vec![5u8; 2592];
        let dirac_era = derive_dilithium("dilithium-v10-padded", &pk);
        let snapshot = vec![to_ss58(&dirac_era)];

        let matches = find_airdrop_matches(snapshot.clone(), Some(pk), None, vec![]).unwrap();
        assert_eq!(matches.len(), 1);
        assert_eq!(matches[0].address, snapshot[0]);
        assert_eq!(matches[0].scheme, "dilithium-v10-padded");
        assert!(matches[0].claimable);
        assert!(matches[0].wormhole_secret.is_none());
    }

    #[test]
    fn rejects_non_quantus_addresses() {
        // Prefix 42 (generic Substrate) must be rejected.
        let generic = AccountId32::new([1u8; 32])
            .to_ss58check_with_version(sp_core::crypto::Ss58AddressFormat::custom(42));
        assert!(find_airdrop_matches(vec![generic], None, None, vec![]).is_err());
    }

    #[test]
    fn dilithium_claim_signature_verifies_with_context() {
        let mut seed = [7u8; 32];
        let keys = ml_dsa_87::Keypair::generate(
            &mut qp_rusty_crystals_dilithium::SensitiveBytes32::new(&mut seed),
        );
        let keypair = super::super::crypto::Keypair {
            public_key: keys.public().to_bytes().to_vec(),
            secret_key: keys.secret().to_bytes().to_vec(),
            scheme: super::super::crypto::DilithiumScheme::MlDsa87,
        };
        let address_bytes = derive_dilithium("dilithium-v10-padded", &keypair.public_key);
        let claim_bytes = [9u8; 32];

        let body =
            build_airdrop_dilithium_claim(&keypair, to_ss58(&address_bytes), to_ss58(&claim_bytes))
                .unwrap();
        assert_eq!(body.scheme, "dilithium-v10-padded");

        let mut msg = [0u8; 72];
        msg[..32].copy_from_slice(&address_bytes);
        msg[32..64].copy_from_slice(&claim_bytes);
        msg[64..].copy_from_slice(&body.expiry_unix.to_be_bytes());
        let sig = hex::decode(&body.signature_hex).unwrap();
        assert!(keys.public().verify(&msg, &sig, Some(CLAIM_CONTEXT)));
        // Context is part of the signature: verification without it must fail.
        assert!(!keys.public().verify(&msg, &sig, None));
    }

    #[test]
    fn dilithium_claim_rejects_foreign_address() {
        let mut seed = [8u8; 32];
        let keys = ml_dsa_87::Keypair::generate(
            &mut qp_rusty_crystals_dilithium::SensitiveBytes32::new(&mut seed),
        );
        let keypair = super::super::crypto::Keypair {
            public_key: keys.public().to_bytes().to_vec(),
            secret_key: keys.secret().to_bytes().to_vec(),
            scheme: super::super::crypto::DilithiumScheme::MlDsa87,
        };
        let err = build_airdrop_dilithium_claim(&keypair, to_ss58(&[3u8; 32]), to_ss58(&[9u8; 32]))
            .unwrap_err();
        assert!(err.contains("does not derive"));
    }

    #[test]
    #[ignore = "builds the ownership circuit; run with --release"]
    fn wormhole_proof_generates() {
        let body = prove_airdrop_wormhole([42u8; 32].to_vec(), to_ss58(&[9u8; 32])).unwrap();
        assert_eq!(body.proof_kind, "wormhole_rate8");
        assert!(!body.proof_hex.is_empty());
    }

    #[test]
    fn hd_scan_finds_wallet_wormhole_address() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        // App external branch, plus a CLI multiround round-2 address: the
        // middle component is a round counter there, not a change branch.
        let paths = [
            format!("m/44'/{}/0'/0'/3'", QUANTUS_WORMHOLE_CHAIN_ID),
            format!("m/44'/{}/0'/2'/1'", QUANTUS_WORMHOLE_CHAIN_ID),
        ];
        let scheme = WORMHOLE_SCHEMES
            .iter()
            .find(|s| s.id == CLAIMABLE_WORMHOLE_SCHEME)
            .unwrap();
        let snapshot: Vec<String> = paths
            .iter()
            .map(|path| {
                let pair =
                    qp_rusty_crystals_hdwallet::derive_wormhole_from_mnemonic(mnemonic, None, path)
                        .unwrap();
                to_ss58(&scheme.derive(pair.secret().as_bytes()))
            })
            .collect();

        let matches =
            find_airdrop_matches(snapshot.clone(), None, Some(mnemonic.into()), vec![]).unwrap();
        assert_eq!(matches.len(), 2);
        let sources: Vec<_> = matches.iter().map(|m| m.source.as_str()).collect();
        assert!(sources.contains(&paths[0].as_str()));
        assert!(sources.contains(&paths[1].as_str()));
        assert!(matches.iter().all(|m| m.claimable));
    }
}
