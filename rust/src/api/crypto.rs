use rusty_crystals_dilithium::*;
use bip39::{Language, Mnemonic};
use poseidon_resonance::PoseidonHasher;
use sp_core::Hasher;
use sp_core::crypto::{AccountId32, Ss58Codec};
#[flutter_rust_bridge::frb(sync)] // Synchronous mode
pub struct Keypair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
}

/// Convert public key to accountId32 in ss58check format
#[flutter_rust_bridge::frb(sync)]
pub fn to_account_id(obj: &Keypair) -> String {
    let hashed = <PoseidonHasher as Hasher>::hash(obj.public_key.as_slice());
    let account = AccountId32::from(hashed.0);
    let result = account.to_ss58check();
    result
 }

#[flutter_rust_bridge::frb(sync)]
impl Keypair {
    fn to_account_id(&self) -> String {
        let public_key = hex::encode(&self.public_key);
        public_key
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_keypair(mnemonic_str: String) -> Keypair {

    // Note this mirrors our implementation in rusty crystals hdwallet
    let mnemonic = Mnemonic::parse_in_normalized(Language::English, &mnemonic_str).expect("Failed to parse mnemonic");

    // Generate seed from mnemonic
    let seed: [u8; 64] = mnemonic.to_seed_normalized(None.unwrap_or(""));

    generate_keypair_from_seed(seed.to_vec())
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_keypair_from_seed(seed: Vec<u8>) -> Keypair {
    let keypair = ml_dsa_87::Keypair::generate(Some(&seed));
    return Keypair {
        public_key: keypair.public.to_bytes().to_vec(),
        secret_key: keypair.secret.to_bytes().to_vec(),
    };
}

#[flutter_rust_bridge::frb(sync)]
pub fn sign_message(keypair: &Keypair, message: &[u8]) -> Vec<u8> {
    let keypair = ml_dsa_87::Keypair{
        secret: ml_dsa_87::SecretKey::from_bytes(&keypair.secret_key),
        public: ml_dsa_87::PublicKey::from_bytes(&keypair.public_key),
    };

    let signature = keypair.sign(&message, None, false).expect("message signing failed");
    signature.as_slice().to_vec()
}

#[flutter_rust_bridge::frb(sync)]
pub fn sign_message_with_pubkey(keypair: &Keypair, message: &[u8]) -> Vec<u8> {
    let signature = sign_message(keypair, message);
    let mut result = Vec::with_capacity(signature.len() + keypair.public_key.len());
    result.extend_from_slice(&signature);
    result.extend_from_slice(&keypair.public_key);
    result
}


#[flutter_rust_bridge::frb(sync)]
pub fn verify_message(keypair: &Keypair, message: &[u8], signature: &[u8]) -> bool {
    let keypair = ml_dsa_87::Keypair{
        secret: ml_dsa_87::SecretKey::from_bytes(&keypair.secret_key),
        public: ml_dsa_87::PublicKey::from_bytes(&keypair.public_key),
    };

    let verified = keypair.verify(&message, &signature, None);
    verified
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
        let signature = sign_message(&keypair, message);
        
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
        let signature = sign_message(&keypair, message);
        
        // Try to verify with a different keypair
        let different_keypair = crystal_bob();
        let is_valid = verify_message(&different_keypair, message, &signature);
        assert!(!is_valid, "Signature should not be valid with different keypair");
    }

    #[test]
    fn test_sign_and_verify_with_empty_message() {
        // Test with an empty message
        let message = b"";
        let keypair = crystal_alice();
        
        // Sign the message
        let signature = sign_message(&keypair, message);
        
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
        let signature = sign_message(&keypair, message);
        
        // Verify the signature
        let is_valid = verify_message(&keypair, message, &signature);
        assert!(is_valid, "Signature verification failed for long message");
    }
}
