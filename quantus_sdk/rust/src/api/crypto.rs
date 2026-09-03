use crate::signing_context;
use qp_poseidon_core::{hash_bytes, hash_to_bytes, serialization::bytes_to_digest};
pub use qp_rusty_crystals_hdwallet::HDLatticeError;
use qp_rusty_crystals_hdwallet::{
    derive_wormhole_from_mnemonic, mnemonic_to_seed, SensitiveBytes32, SensitiveBytes64,
};
use sp_core::crypto::{AccountId32, Ss58Codec};
use std::convert::AsRef;

/// SS58 network prefix of the Quantus chain. Must match the chain runtime
/// (`Ss58AddressFormat::custom(189)`) and `AppConstants.ss58prefix` in Dart.
const QUANTUS_SS58_PREFIX: u16 = 189;

/// ML-DSA parameter set of a keypair. Mirrors quantus-cli's `DilithiumScheme`;
/// accounts stored before this existed are ML-DSA-87.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DilithiumScheme {
    MlDsa65,
    MlDsa87,
}

/// Runs `$body` with `$dsa` and `$hd` bound to the `ml_dsa_65` or `ml_dsa_87`
/// modules of the dilithium and hdwallet crates selected by `$scheme`.
macro_rules! dispatch {
    ($scheme:expr, $dsa:ident, $hd:ident, $body:block) => {
        match $scheme {
            DilithiumScheme::MlDsa65 => {
                #[allow(unused_imports)]
                use qp_rusty_crystals_dilithium::ml_dsa_65 as $dsa;
                #[allow(unused_imports)]
                use qp_rusty_crystals_hdwallet::ml_dsa_65 as $hd;
                $body
            }
            DilithiumScheme::MlDsa87 => {
                #[allow(unused_imports)]
                use qp_rusty_crystals_dilithium::ml_dsa_87 as $dsa;
                #[allow(unused_imports)]
                use qp_rusty_crystals_hdwallet::ml_dsa_87 as $hd;
                $body
            }
        }
    };
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_default_ss58_prefix(prefix: u16) {
    sp_core::crypto::set_default_ss58_version(sp_core::crypto::Ss58AddressFormat::custom(prefix));
}

#[flutter_rust_bridge::frb(sync)]
pub struct Keypair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
    pub scheme: DilithiumScheme,
}

impl Keypair {
    fn new(scheme: DilithiumScheme, public_key: impl AsRef<[u8]>, secret_key: impl AsRef<[u8]>) -> Self {
        Keypair {
            public_key: public_key.as_ref().to_vec(),
            secret_key: secret_key.as_ref().to_vec(),
            scheme,
        }
    }
}

fn ml_dsa_87_from_entropy(entropy: &mut SensitiveBytes32) -> Keypair {
    let keypair = qp_rusty_crystals_dilithium::ml_dsa_87::Keypair::generate(entropy);
    Keypair::new(
        DilithiumScheme::MlDsa87,
        keypair.public().to_bytes(),
        keypair.secret().to_bytes(),
    )
}

/// Convert public key to accountId32 in ss58check format
#[flutter_rust_bridge::frb(sync)]
pub fn to_account_id(obj: &Keypair) -> String {
    let hashed = hash_bytes(obj.public_key.as_slice());
    let account = AccountId32::new(hashed);
    account.to_ss58check()
}
/// Convert key in ss58check format to accountId32
#[flutter_rust_bridge::frb(sync)]
pub fn ss58_to_account_id(s: &str) -> Result<Vec<u8>, String> {
    // Only accept Quantus addresses: a foreign-chain prefix would decode to an
    // uncontrolled AccountId32 on Quantus and burn any funds sent to it.
    let (account, version) = AccountId32::from_ss58check_with_version(s)
        .map_err(|e| format!("Invalid ss58 address: {:?}", e))?;
    let prefix = u16::from(version);
    if prefix != QUANTUS_SS58_PREFIX {
        return Err(format!(
            "Wrong ss58 network prefix: expected {} (Quantus), got {}",
            QUANTUS_SS58_PREFIX, prefix
        ));
    }
    Ok(AsRef::<[u8]>::as_ref(&account).to_vec())
}

/// Legacy non-HD ML-DSA-87 keypair straight from the mnemonic seed (early CLI and miner accounts).
#[flutter_rust_bridge::frb(sync)]
pub fn generate_keypair(mnemonic_str: String) -> Result<Keypair, HDLatticeError> {
    let mut seed64 = SensitiveBytes64::zeroed();
    mnemonic_to_seed(mnemonic_str, None, &mut seed64)?;
    let mut entropy = SensitiveBytes32::zeroed();
    entropy
        .as_mut_bytes()
        .copy_from_slice(&seed64.as_bytes()[..32]);
    Ok(ml_dsa_87_from_entropy(&mut entropy))
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_derived_keypair(
    mnemonic_str: String,
    path: &str,
    scheme: DilithiumScheme,
) -> Result<Keypair, HDLatticeError> {
    dispatch!(scheme, dsa, hd, {
        let keypair = hd::derive_key_from_mnemonic(&mnemonic_str, None, path)?;
        Ok(Keypair::new(
            scheme,
            keypair.public().to_bytes(),
            keypair.secret().to_bytes(),
        ))
    })
}

#[flutter_rust_bridge::frb(sync)]
pub struct WormholeResult {
    pub address: String,
    pub first_hash: Vec<u8>,
    pub secret: Vec<u8>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn derive_wormhole(mnemonic_str: String, path: &str) -> Result<WormholeResult, HDLatticeError> {
    let pair = derive_wormhole_from_mnemonic(&mnemonic_str, None, path)?;
    let account = AccountId32::new(*pair.address());
    Ok(WormholeResult {
        address: account.to_ss58check(),
        first_hash: pair.first_hash().to_vec(),
        secret: pair.secret().as_bytes().to_vec(),
    })
}

/// Convert a first_hash (rewards preimage) to its corresponding wormhole address.
///
/// Mirrors how the chain and ZK circuit derive the address from the preimage:
/// - Convert 32 bytes → 4 Poseidon field elements (8 bytes each)
/// - Hash once without padding
#[flutter_rust_bridge::frb(sync)]
pub fn first_hash_to_address(first_hash_hex: String) -> Result<String, String> {
    let hex_str = first_hash_hex.trim_start_matches("0x");
    let first_hash_bytes: [u8; 32] = hex::decode(hex_str)
        .map_err(|e| format!("Invalid hex string: {}", e))?
        .try_into()
        .map_err(|_| "First hash must be exactly 32 bytes".to_string())?;

    let first_hash_felts: [_; 4] = bytes_to_digest(&first_hash_bytes)
        .map_err(|e| format!("Failed to convert first_hash to digest: {:?}", e))?;
    let address_bytes = hash_to_bytes(&first_hash_felts);

    let account = AccountId32::from(address_bytes);
    Ok(account.to_ss58check())
}

/// ML-DSA-87 keypair from a raw 32-byte seed (dev accounts).
#[flutter_rust_bridge::frb(sync)]
pub fn generate_keypair_from_seed(seed: Vec<u8>) -> Keypair {
    let mut seed_array: [u8; 32] = seed.try_into().expect("Seed must be 32 bytes");
    let mut entropy = SensitiveBytes32::new(&mut seed_array);
    ml_dsa_87_from_entropy(&mut entropy)
}

/// Signs `message`. Spec 148+ uses [`signing_context::EXTRINSIC`]; earlier specs use none.
#[flutter_rust_bridge::frb(sync)]
pub fn sign_message(
    keypair: &Keypair,
    message: &[u8],
    entropy: Option<[u8; 32]>,
    spec_version: u32,
) -> Vec<u8> {
    let mut entropy = entropy;
    let hedge = entropy.as_mut().map(SensitiveBytes32::new);
    let context = signing_context::context_for_spec(spec_version);
    dispatch!(keypair.scheme, dsa, hd, {
        let secret =
            dsa::SecretKey::from_bytes(&keypair.secret_key).expect("Failed to parse secret key");
        let public =
            dsa::PublicKey::from_bytes(&keypair.public_key).expect("Failed to parse public key");
        let ml_dsa_keypair =
            dsa::Keypair::from_parts(secret, public).expect("Keypair halves do not correspond");
        ml_dsa_keypair
            .sign(message, context, hedge.as_ref())
            .expect("Signing failed")
            .to_vec()
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn sign_message_with_pubkey(
    keypair: &Keypair,
    message: &[u8],
    entropy: Option<[u8; 32]>,
    spec_version: u32,
) -> Vec<u8> {
    let signature = sign_message(keypair, message, entropy, spec_version);
    let mut result = Vec::with_capacity(signature.len() + keypair.public_key.len());
    result.extend_from_slice(&signature);
    result.extend_from_slice(&keypair.public_key);
    result
}

/// Verifies under the same context [`sign_message`] would use for `spec_version`.
#[flutter_rust_bridge::frb(sync)]
pub fn verify_message(
    keypair: &Keypair,
    message: &[u8],
    signature: &[u8],
    spec_version: u32,
) -> bool {
    let context = signing_context::context_for_spec(spec_version);
    dispatch!(keypair.scheme, dsa, hd, {
        let public =
            dsa::PublicKey::from_bytes(&keypair.public_key).expect("Failed to parse public key");
        public.verify(message, signature, context)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn crystal_alice() -> Keypair {
    generate_keypair_from_seed(vec![0; 32])
}

#[flutter_rust_bridge::frb(sync)]
pub fn crystal_bob() -> Keypair {
    generate_keypair_from_seed(vec![1; 32])
}

#[flutter_rust_bridge::frb(sync)]
pub fn crystal_charlie() -> Keypair {
    generate_keypair_from_seed(vec![2; 32])
}

#[flutter_rust_bridge::frb(sync)]
pub fn public_key_bytes(scheme: DilithiumScheme) -> u32 {
    dispatch!(scheme, dsa, hd, { dsa::PUBLICKEYBYTES as u32 })
}

#[flutter_rust_bridge::frb(sync)]
pub fn secret_key_bytes(scheme: DilithiumScheme) -> u32 {
    dispatch!(scheme, dsa, hd, { dsa::SECRETKEYBYTES as u32 })
}

#[flutter_rust_bridge::frb(sync)]
pub fn signature_bytes(scheme: DilithiumScheme) -> u32 {
    dispatch!(scheme, dsa, hd, { dsa::SIGNBYTES as u32 })
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;
    use qp_rusty_crystals_dilithium::{ml_dsa_65, ml_dsa_87};

    const SPEC_WITH_CONTEXT: u32 = signing_context::EXTRINSIC_MIN_SPEC;
    const SPEC_WITHOUT_CONTEXT: u32 = signing_context::EXTRINSIC_MIN_SPEC - 1;

    /// Shared with quantus-cli `test_known_values` and the Dart `generate_keys_test`.
    const TEST_MNEMONIC: &str = "orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven";
    const PATH_87_INDEX_0: &str = "m/44'/189189'/0'/0'/0'";
    const PATH_65_INDEX_0: &str = "m/44'/189189'/0'/0'/1'";
    const KNOWN_ADDRESS_87_INDEX_0: &str = "qzm5QCox8Dp5A3oSXZZYHD8YoYgPz7enykZb6RPUropdCyN5h";
    /// `quantus wallet import --scheme ml-dsa-65` (default path) for the same mnemonic.
    const KNOWN_ADDRESS_65_INDEX_0: &str = "qzoyC4eRTrexYoutXABVsf61QJZxJim3iWvayRQwEjXWgA4mw";

    fn set_prefix() {
        set_default_ss58_prefix(QUANTUS_SS58_PREFIX);
    }

    fn derived(path: &str, scheme: DilithiumScheme) -> Keypair {
        generate_derived_keypair(TEST_MNEMONIC.to_string(), path, scheme).expect("derive")
    }

    #[test]
    fn test_sign_and_verify() {
        let message = b"Hello, World!";
        let keypair = crystal_alice();
        let signature = sign_message(&keypair, message, None, SPEC_WITH_CONTEXT);
        let is_valid = verify_message(&keypair, message, &signature, SPEC_WITH_CONTEXT);
        assert!(is_valid, "Signature verification failed");
    }

    #[test]
    fn test_context_for_spec() {
        assert_eq!(signing_context::context_for_spec(147), None);
        assert_eq!(
            signing_context::context_for_spec(148),
            Some(signing_context::EXTRINSIC)
        );
        assert_eq!(
            signing_context::context_for_spec(149),
            Some(signing_context::EXTRINSIC)
        );
    }

    #[test]
    fn test_signature_is_bound_to_the_extrinsic_context() {
        let message = b"Hello, World!";
        let keypair = crystal_alice();
        let signature = sign_message(&keypair, message, None, SPEC_WITH_CONTEXT);
        let public = ml_dsa_87::PublicKey::from_bytes(&keypair.public_key).unwrap();

        assert_eq!(signing_context::EXTRINSIC, b"QUANTUS_EXTRINSIC");
        assert!(public.verify(message, &signature, Some(signing_context::EXTRINSIC)));
        assert!(!public.verify(message, &signature, None));
        assert!(verify_message(
            &keypair,
            message,
            &signature,
            SPEC_WITH_CONTEXT
        ));
        assert!(!verify_message(
            &keypair,
            message,
            &signature,
            SPEC_WITHOUT_CONTEXT
        ));
    }

    #[test]
    fn test_pre_148_signs_with_empty_context() {
        let message = b"Hello, World!";
        let keypair = crystal_alice();
        let signature = sign_message(&keypair, message, None, SPEC_WITHOUT_CONTEXT);
        let public = ml_dsa_87::PublicKey::from_bytes(&keypair.public_key).unwrap();

        assert!(public.verify(message, &signature, None));
        assert!(!public.verify(message, &signature, Some(signing_context::EXTRINSIC)));
        assert!(verify_message(
            &keypair,
            message,
            &signature,
            SPEC_WITHOUT_CONTEXT
        ));
        assert!(!verify_message(
            &keypair,
            message,
            &signature,
            SPEC_WITH_CONTEXT
        ));
    }

    #[test]
    fn test_sign_and_verify_with_different_keypair() {
        let message = b"Hello, World!";
        let keypair = crystal_alice();
        let signature = sign_message(&keypair, message, None, SPEC_WITH_CONTEXT);
        let different_keypair = crystal_bob();
        let is_valid = verify_message(&different_keypair, message, &signature, SPEC_WITH_CONTEXT);
        assert!(
            !is_valid,
            "Signature should not be valid with different keypair"
        );
    }

    #[test]
    fn test_sign_and_verify_with_empty_message() {
        let message = b"";
        let keypair = crystal_alice();
        let signature = sign_message(&keypair, message, None, SPEC_WITH_CONTEXT);
        let is_valid = verify_message(&keypair, message, &signature, SPEC_WITH_CONTEXT);
        assert!(is_valid, "Signature verification failed for empty message");
    }

    #[test]
    fn test_sign_and_verify_with_long_message() {
        let message = b"This is a longer message that should also work correctly with our signing and verification process.";
        let keypair = crystal_alice();
        let signature = sign_message(&keypair, message, None, SPEC_WITH_CONTEXT);
        let is_valid = verify_message(&keypair, message, &signature, SPEC_WITH_CONTEXT);
        assert!(is_valid, "Signature verification failed for long message");
    }

    #[test]
    fn test_legacy_constructors_are_ml_dsa_87() {
        assert_eq!(crystal_alice().scheme, DilithiumScheme::MlDsa87);
        assert_eq!(
            generate_keypair(TEST_MNEMONIC.to_string()).unwrap().scheme,
            DilithiumScheme::MlDsa87
        );
    }

    #[test]
    fn test_sizes_per_scheme() {
        assert_eq!(public_key_bytes(DilithiumScheme::MlDsa65), 1952);
        assert_eq!(secret_key_bytes(DilithiumScheme::MlDsa65), 4032);
        assert_eq!(signature_bytes(DilithiumScheme::MlDsa65), 3309);
        assert_eq!(public_key_bytes(DilithiumScheme::MlDsa87), 2592);
        assert_eq!(secret_key_bytes(DilithiumScheme::MlDsa87), 4896);
        assert_eq!(signature_bytes(DilithiumScheme::MlDsa87), 4627);
    }

    #[test]
    fn test_derived_keypair_matches_scheme_sizes() {
        for scheme in [DilithiumScheme::MlDsa65, DilithiumScheme::MlDsa87] {
            let keypair = derived(PATH_87_INDEX_0, scheme);
            assert_eq!(keypair.scheme, scheme);
            assert_eq!(keypair.public_key.len(), public_key_bytes(scheme) as usize);
            assert_eq!(keypair.secret_key.len(), secret_key_bytes(scheme) as usize);
            let signed = sign_message_with_pubkey(&keypair, b"msg", None, SPEC_WITH_CONTEXT);
            assert_eq!(
                signed.len(),
                (signature_bytes(scheme) + public_key_bytes(scheme)) as usize
            );
        }
    }

    #[test]
    fn test_ml_dsa_65_sign_and_verify_with_context() {
        let message = b"Hello, World!";
        let keypair = derived(PATH_65_INDEX_0, DilithiumScheme::MlDsa65);
        let signature = sign_message(&keypair, message, None, SPEC_WITH_CONTEXT);
        let public = ml_dsa_65::PublicKey::from_bytes(&keypair.public_key).unwrap();

        assert_eq!(signature.len(), 3309);
        assert!(public.verify(message, &signature, Some(signing_context::EXTRINSIC)));
        assert!(!public.verify(message, &signature, None));
        assert!(verify_message(
            &keypair,
            message,
            &signature,
            SPEC_WITH_CONTEXT
        ));
        assert!(!verify_message(
            &keypair,
            message,
            &signature,
            SPEC_WITHOUT_CONTEXT
        ));

        let other = derived(PATH_87_INDEX_0, DilithiumScheme::MlDsa87);
        assert!(!verify_message(&other, message, &signature, SPEC_WITH_CONTEXT));
    }

    #[test]
    fn test_known_ml_dsa_87_address() {
        set_prefix();
        let keypair = derived(PATH_87_INDEX_0, DilithiumScheme::MlDsa87);
        assert_eq!(to_account_id(&keypair), KNOWN_ADDRESS_87_INDEX_0);
    }

    #[test]
    fn test_known_ml_dsa_65_address_matches_cli() {
        set_prefix();
        let keypair = derived(PATH_65_INDEX_0, DilithiumScheme::MlDsa65);
        assert_eq!(to_account_id(&keypair), KNOWN_ADDRESS_65_INDEX_0);
    }

    #[test]
    fn test_schemes_never_share_an_address() {
        set_prefix();
        let a87 = to_account_id(&derived(PATH_87_INDEX_0, DilithiumScheme::MlDsa87));
        let a65 = to_account_id(&derived(PATH_65_INDEX_0, DilithiumScheme::MlDsa65));
        let a65_same_path = to_account_id(&derived(PATH_87_INDEX_0, DilithiumScheme::MlDsa65));
        assert_ne!(a87, a65);
        assert_ne!(a87, a65_same_path);
        assert_ne!(a65, a65_same_path);
    }
}
