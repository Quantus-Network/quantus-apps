use nam_tiny_hderive::bip32::ExtendedPrivKey;
use qp_poseidon::PoseidonHasher;
use qp_rusty_crystals_dilithium::ml_dsa_87;
use qp_rusty_crystals_hdwallet::{derive_key_from_mnemonic, SensitiveBytes32};
pub use qp_rusty_crystals_hdwallet::HDLatticeError;
use sp_core::crypto::{AccountId32, Ss58Codec};
use sp_core::Hasher;
use std::convert::AsRef;

type MlDsaKeypair = ml_dsa_87::Keypair;
const DEFAULT_DERIVATION_PATH: &str = "m/44'/189189'/0'/0'/0'";

#[flutter_rust_bridge::frb(sync)]
pub fn set_default_ss58_prefix(prefix: u16) {
    sp_core::crypto::set_default_ss58_version(sp_core::crypto::Ss58AddressFormat::custom(prefix));
}

#[flutter_rust_bridge::frb(sync)]
pub struct Keypair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
}

impl Keypair {
    fn from_ml_dsa(ml_dsa_keypair: MlDsaKeypair) -> Self {
        Keypair {
            public_key: ml_dsa_keypair.public.to_bytes().to_vec(),
            secret_key: ml_dsa_keypair.secret.to_bytes().to_vec(),
        }
    }

    fn to_ml_dsa(&self) -> MlDsaKeypair {
        MlDsaKeypair {
            secret: ml_dsa_87::SecretKey::from_bytes(&self.secret_key)
                .expect("Failed to parse secret key"),
            public: ml_dsa_87::PublicKey::from_bytes(&self.public_key)
                .expect("Failed to parse public key"),
        }
    }
}

/// Convert public key to accountId32 in ss58check format
#[flutter_rust_bridge::frb(sync)]
pub fn to_account_id(obj: &Keypair) -> String {
    let hashed = <PoseidonHasher as Hasher>::hash(obj.public_key.as_slice());
    let account = AccountId32::from(hashed.0);
    account.to_ss58check()
}
/// Convert key in ss58check format to accountId32
#[flutter_rust_bridge::frb(sync)]
pub fn ss58_to_account_id(s: &str) -> Vec<u8> {
    // from_ss58check returns a Result, we unwrap it to panic on invalid input.
    // We then convert the AccountId32 struct to a Vec<u8> to be compatible with Polkadart's typedef.
    AsRef::<[u8]>::as_ref(&AccountId32::from_ss58check(s).unwrap()).to_vec()
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_keypair(mnemonic_str: String) -> Keypair {
    let ml_dsa_keypair = derive_key_from_mnemonic(&mnemonic_str, None, DEFAULT_DERIVATION_PATH)
        .expect("Failed to derive keypair from mnemonic");
    Keypair::from_ml_dsa(ml_dsa_keypair)
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_derived_keypair(mnemonic_str: String, path: &str) -> Result<Keypair, HDLatticeError> {
    derive_key_from_mnemonic(&mnemonic_str, None, path).map(Keypair::from_ml_dsa)
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_keypair_from_seed(seed: Vec<u8>) -> Keypair {
    let mut seed_array: [u8; 32] = seed.try_into().expect("Seed must be 32 bytes");
    let ml_dsa_keypair = MlDsaKeypair::generate(SensitiveBytes32::new(&mut seed_array));
    Keypair::from_ml_dsa(ml_dsa_keypair)
}

#[flutter_rust_bridge::frb(sync)]
pub fn sign_message(keypair: &Keypair, message: &[u8], entropy: Option<[u8; 32]>) -> Vec<u8> {
    let ml_dsa_keypair = keypair.to_ml_dsa();
    let signature = ml_dsa_keypair.sign(message, None, entropy)
        .expect("Signing failed");
    signature.to_vec()
}

#[flutter_rust_bridge::frb(sync)]
pub fn sign_message_with_pubkey(keypair: &Keypair, message: &[u8], entropy: Option<[u8; 32]>) -> Vec<u8> {
    let signature = sign_message(keypair, message, entropy);
    let mut result = Vec::with_capacity(signature.len() + keypair.public_key.len());
    result.extend_from_slice(&signature);
    result.extend_from_slice(&keypair.public_key);
    result
}

#[flutter_rust_bridge::frb(sync)]
pub fn verify_message(keypair: &Keypair, message: &[u8], signature: &[u8]) -> bool {
    let ml_dsa_keypair = keypair.to_ml_dsa();
    ml_dsa_keypair.verify(&message, &signature, None)
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
pub fn derive_hd_path(seed: Vec<u8>, path: String) -> Vec<u8> {
    let seed = seed.as_slice();
    let path = path.as_str();
    let ext = ExtendedPrivKey::derive(seed, path).expect("Failed to derive HD path");
    return ext.secret().to_vec();
}

#[flutter_rust_bridge::frb(sync)]
pub fn public_key_bytes() -> usize {
    ml_dsa_87::PUBLICKEYBYTES
}

#[flutter_rust_bridge::frb(sync)]
pub fn secret_key_bytes() -> usize {
    ml_dsa_87::SECRETKEYBYTES
}

#[flutter_rust_bridge::frb(sync)]
pub fn signature_bytes() -> usize {
    ml_dsa_87::SIGNBYTES
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sign_and_verify() {
        // Test with a simple message
        let message = b"Hello, World!";
        let keypair = crystal_alice();

        // Sign the message
        let signature = sign_message(&keypair, message, None);

        // Verify the signature
        let is_valid = verify_message(&keypair, message, &signature);
        assert!(is_valid, "Signature verification failed");
    }

    #[test]
    fn test_sign_and_verify_with_different_keypair() {
        // Test with a simple message
        let message = b"Hello, World!";
        let keypair = crystal_alice();

        // Sign the message
        let signature = sign_message(&keypair, message, None);

        // Try to verify with a different keypair
        let different_keypair = crystal_bob();
        let is_valid = verify_message(&different_keypair, message, &signature);
        assert!(
            !is_valid,
            "Signature should not be valid with different keypair"
        );
    }

    #[test]
    fn test_sign_and_verify_with_empty_message() {
        // Test with an empty message
        let message = b"";
        let keypair = crystal_alice();

        // Sign the message
        let signature = sign_message(&keypair, message, None);

        // Verify the signature
        let is_valid = verify_message(&keypair, message, &signature);
        assert!(is_valid, "Signature verification failed for empty message");
    }

    #[test]
    fn test_sign_and_verify_with_long_message() {
        // Test with a longer message
        let message = b"This is a longer message that should also work correctly with our signing and verification process.";
        let keypair = crystal_alice();

        // Sign the message
        let signature = sign_message(&keypair, message, None);

        // Verify the signature
        let is_valid = verify_message(&keypair, message, &signature);
        assert!(is_valid, "Signature verification failed for long message");
    }
}
