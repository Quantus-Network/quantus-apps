use rusty_crystals_dilithium::*;
use bip39::{Language, Mnemonic};
// use poseidon_resonance::PoseidonHasher;
// use sp_core::Hasher;
#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub struct Keypair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn to_account_id(obj: &Keypair) -> String {
    // let hashed = <PoseidonHasher as Hasher>::hash(obj.public_key.as_slice());
    let hashed = obj.public_key.as_slice();
    let account = hex::encode(hashed);
    account
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
    let mnemonic = Mnemonic::parse_in_normalized(Language::English, &mnemonic_str).expect("Failed to parse mnemonic");

    // Generate seed from mnemonic
    let seed: [u8; 64] = mnemonic.to_seed_normalized(None.unwrap_or(""));

    generate_keypair_from_seed(seed.to_vec())
    // let keypair = ml_dsa_87::Keypair::generate(Some(&seed));
    // return Keypair {
    //     public_key: keypair.public.to_bytes().to_vec(),
    //     secret_key: keypair.secret.to_bytes().to_vec(),
    // };
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
