#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub struct Keypair {
    pub public_key: Vec<u8>,
    pub secret_key: Vec<u8>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn to_account_id(obj: Keypair) -> String {
    let public_key = hex::encode(&obj.public_key);
    public_key
 }

#[flutter_rust_bridge::frb(sync)]
impl Keypair {
    fn to_account_id(&self) -> String {
        let public_key = hex::encode(&self.public_key);
        public_key
    }
}


#[flutter_rust_bridge::frb(sync)]
pub fn generateKeypair(mnemonic: String) -> Keypair {
    return Keypair {
        public_key: vec![0; 32],
        secret_key: vec![0; 32],
    };
}




#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
