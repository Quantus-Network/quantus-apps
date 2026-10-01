//! NEAR transactions for the cold wallet: decode for display, sign with an
//! ML-DSA-65 account.
//!
//! NEAR accepts FIPS 204 ML-DSA-65 access keys and signatures from protocol
//! version 85. A cold-wallet request (signing envelope v2, see
//! `signing_request.dart`) carries the borsh-encoded `TransactionV0` raw, so
//! the device can show every action before signing. The device signs
//! `SHA-256(borsh(tx))` as a *pure* ML-DSA-65 signature with an **empty**
//! context — NEAR verifies without one, so [`crate::signing_context`] must
//! not be applied here — and answers `signature[3309] ‖ public_key[1952]`,
//! the same shape as a Quantus extrinsic response.
//!
//! The wire layout mirrors nearcore (`core/primitives/src/transaction.rs`,
//! `core/crypto/src/signature.rs`) and quantus-cli's `near::protocol`. Enum
//! variants are borsh u8 tags in declaration order; every position must stay.

use crate::api::crypto::{DilithiumScheme, Keypair};
use borsh::{BorshDeserialize, BorshSerialize};
use qp_rusty_crystals_dilithium::ml_dsa_65;
use qp_rusty_crystals_hdwallet::SensitiveBytes32;
use sha2::{Digest, Sha256};
use sha3::Sha3_256;

pub const ML_DSA_65_PUBLIC_KEY_LEN: usize = 1952;
pub const ML_DSA_65_SIGNATURE_LEN: usize = 3309;

/// Domain-separation tag nearcore hashes before the raw public key to form
/// the on-chain access-key handle (`ml-dsa-65-hash:` text form).
const ML_DSA_65_HANDLE_DOMAIN_TAG: &[u8] = b"near:ml-dsa-65-pubkey-hash:v1";

// ---- borsh wire types -------------------------------------------------------

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
enum WirePublicKey {
    Ed25519([u8; 32]),
    Secp256k1(Box<[u8; 64]>),
    MlDsa65(Box<[u8; ML_DSA_65_PUBLIC_KEY_LEN]>),
}

impl WirePublicKey {
    fn text(&self) -> String {
        match self {
            WirePublicKey::Ed25519(b) => format!("ed25519:{}", bs58::encode(b).into_string()),
            WirePublicKey::Secp256k1(b) => {
                format!("secp256k1:{}", bs58::encode(b.as_ref()).into_string())
            }
            WirePublicKey::MlDsa65(b) => {
                format!("ml-dsa-65:{}", bs58::encode(b.as_ref()).into_string())
            }
        }
    }

    fn bytes(&self) -> Vec<u8> {
        match self {
            WirePublicKey::Ed25519(b) => b.to_vec(),
            WirePublicKey::Secp256k1(b) => b.to_vec(),
            WirePublicKey::MlDsa65(b) => b.to_vec(),
        }
    }
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
struct WireAccessKey {
    nonce: u64,
    permission: WireAccessKeyPermission,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
enum WireAccessKeyPermission {
    FunctionCall(WireFunctionCallPermission),
    FullAccess,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
struct WireFunctionCallPermission {
    allowance: Option<u128>,
    receiver_id: String,
    method_names: Vec<String>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
enum WireAction {
    CreateAccount,
    DeployContract {
        code: Vec<u8>,
    },
    FunctionCall {
        method_name: String,
        args: Vec<u8>,
        gas: u64,
        deposit: u128,
    },
    Transfer {
        deposit: u128,
    },
    Stake {
        stake: u128,
        public_key: WirePublicKey,
    },
    AddKey {
        public_key: WirePublicKey,
        access_key: WireAccessKey,
    },
    DeleteKey {
        public_key: WirePublicKey,
    },
    DeleteAccount {
        beneficiary_id: String,
    },
}

/// nearcore `TransactionV0`: the signable body wallets produce.
#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
struct WireTransaction {
    signer_id: String,
    public_key: WirePublicKey,
    nonce: u64,
    receiver_id: String,
    block_hash: [u8; 32],
    actions: Vec<WireAction>,
}

// ---- Dart-facing model -------------------------------------------------------

/// The kind of a [`NearAction`]. Everything but `Transfer` and
/// `FunctionCall` changes who controls the account or what code it runs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum NearActionKind {
    CreateAccount,
    DeployContract,
    FunctionCall,
    #[default]
    Transfer,
    Stake,
    AddKey,
    DeleteKey,
    DeleteAccount,
}

/// One action of a NEAR transaction, flattened for display. Which fields are
/// set depends on [`NearAction::kind`]; amounts are yoctoNEAR (24 decimals)
/// and keys are NEAR text form (`<scheme>:<base58>`).
///
/// A flat struct rather than an enum with payloads: that keeps the Dart side
/// a plain class instead of a generated sealed hierarchy.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct NearAction {
    pub kind: NearActionKind,
    /// `FunctionCall`: the method; `DeleteAccount`: the beneficiary;
    /// `AddKey` (function-call key): the contract the key may call.
    pub target: Option<String>,
    /// `FunctionCall`: raw call arguments (usually JSON).
    pub args: Option<Vec<u8>>,
    /// `FunctionCall`: prepaid gas.
    pub gas: Option<u64>,
    /// `Transfer`/`FunctionCall`: attached deposit; `Stake`: staked amount;
    /// `AddKey` (function-call key): gas allowance, `None` = unlimited.
    pub amount: Option<u128>,
    /// `Stake`/`AddKey`/`DeleteKey`: the key concerned.
    pub public_key: Option<String>,
    /// `AddKey`: whether the key gets full access.
    pub full_access: bool,
    /// `AddKey` (function-call key): the methods it may call; empty = any.
    pub method_names: Vec<String>,
    /// `DeployContract`: size of the code blob.
    pub code_len: Option<u32>,
}

impl From<&WireAction> for NearAction {
    fn from(action: &WireAction) -> Self {
        match action {
            WireAction::CreateAccount => NearAction {
                kind: NearActionKind::CreateAccount,
                ..Default::default()
            },
            WireAction::DeployContract { code } => NearAction {
                kind: NearActionKind::DeployContract,
                code_len: Some(code.len() as u32),
                ..Default::default()
            },
            WireAction::FunctionCall {
                method_name,
                args,
                gas,
                deposit,
            } => NearAction {
                kind: NearActionKind::FunctionCall,
                target: Some(method_name.clone()),
                args: Some(args.clone()),
                gas: Some(*gas),
                amount: Some(*deposit),
                ..Default::default()
            },
            WireAction::Transfer { deposit } => NearAction {
                kind: NearActionKind::Transfer,
                amount: Some(*deposit),
                ..Default::default()
            },
            WireAction::Stake { stake, public_key } => NearAction {
                kind: NearActionKind::Stake,
                amount: Some(*stake),
                public_key: Some(public_key.text()),
                ..Default::default()
            },
            WireAction::AddKey {
                public_key,
                access_key,
            } => match &access_key.permission {
                WireAccessKeyPermission::FullAccess => NearAction {
                    kind: NearActionKind::AddKey,
                    public_key: Some(public_key.text()),
                    full_access: true,
                    ..Default::default()
                },
                WireAccessKeyPermission::FunctionCall(p) => NearAction {
                    kind: NearActionKind::AddKey,
                    public_key: Some(public_key.text()),
                    full_access: false,
                    target: Some(p.receiver_id.clone()),
                    amount: p.allowance,
                    method_names: p.method_names.clone(),
                    ..Default::default()
                },
            },
            WireAction::DeleteKey { public_key } => NearAction {
                kind: NearActionKind::DeleteKey,
                public_key: Some(public_key.text()),
                ..Default::default()
            },
            WireAction::DeleteAccount { beneficiary_id } => NearAction {
                kind: NearActionKind::DeleteAccount,
                target: Some(beneficiary_id.clone()),
                ..Default::default()
            },
        }
    }
}

/// A decoded NEAR transaction, ready to display.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NearTransaction {
    pub signer_id: String,
    /// The key that must sign, in NEAR text form.
    pub public_key: String,
    /// Raw bytes of that key; compare against a [`Keypair::public_key`].
    pub public_key_bytes: Vec<u8>,
    /// Whether the signing key is ML-DSA-65 — the only scheme a Quantus
    /// account can sign for.
    pub signs_with_ml_dsa_65: bool,
    pub nonce: u64,
    pub receiver_id: String,
    /// Base58, as NEAR tooling prints it.
    pub block_hash: String,
    /// SHA-256 of the transaction bytes: what gets signed, and the id the
    /// NEAR RPC reports (as base58) once submitted.
    pub hash: Vec<u8>,
    pub actions: Vec<NearAction>,
}

fn decode_wire(bytes: &[u8]) -> Result<WireTransaction, String> {
    let wire: WireTransaction =
        borsh::from_slice(bytes).map_err(|e| format!("Not a borsh NEAR transaction: {e}"))?;
    check_account_id("signer", &wire.signer_id)?;
    check_account_id("receiver", &wire.receiver_id)?;
    for action in &wire.actions {
        match action {
            WireAction::DeleteAccount { beneficiary_id } => {
                check_account_id("beneficiary", beneficiary_id)?
            }
            WireAction::AddKey { access_key, .. } => {
                if let WireAccessKeyPermission::FunctionCall(p) = &access_key.permission {
                    check_account_id("key receiver", &p.receiver_id)?
                }
            }
            _ => {}
        }
    }
    Ok(wire)
}

/// NEAR's account id rules: 2–64 chars of `a-z 0-9 _ - .`, separators never
/// doubled or at either end of a part. The chain refuses anything else, and
/// the check also keeps every account id shown to a signer plain ASCII.
fn check_account_id(role: &str, id: &str) -> Result<(), String> {
    let valid = (2..=64).contains(&id.len())
        && id.split('.').all(|part| {
            !part.is_empty()
                && !part.starts_with(['-', '_'])
                && !part.ends_with(['-', '_'])
                && !part.contains("--")
                && !part.contains("__")
                && !part.contains("-_")
                && !part.contains("_-")
                && part
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'_')
        });
    if valid {
        Ok(())
    } else {
        Err(format!("Not a NEAR account id ({role}): {id:?}"))
    }
}

/// Decode a borsh `TransactionV0`. Refuses trailing bytes.
#[flutter_rust_bridge::frb(sync)]
pub fn decode_near_transaction(transaction: Vec<u8>) -> Result<NearTransaction, String> {
    let wire = decode_wire(&transaction)?;
    Ok(NearTransaction {
        signer_id: wire.signer_id.clone(),
        public_key: wire.public_key.text(),
        public_key_bytes: wire.public_key.bytes(),
        signs_with_ml_dsa_65: matches!(wire.public_key, WirePublicKey::MlDsa65(_)),
        nonce: wire.nonce,
        receiver_id: wire.receiver_id.clone(),
        block_hash: bs58::encode(wire.block_hash).into_string(),
        hash: Sha256::digest(&transaction).to_vec(),
        actions: wire.actions.iter().map(NearAction::from).collect(),
    })
}

/// SHA-256 of the transaction bytes: the message NEAR signs and verifies.
#[flutter_rust_bridge::frb(sync)]
pub fn near_transaction_hash(transaction: Vec<u8>) -> Vec<u8> {
    Sha256::digest(&transaction).to_vec()
}

fn require_ml_dsa_65(keypair: &Keypair) -> Result<(), String> {
    if keypair.scheme != DilithiumScheme::MlDsa65 {
        return Err("NEAR accepts ML-DSA-65 keys only; this account is ML-DSA-87".to_string());
    }
    Ok(())
}

/// Sign a borsh `TransactionV0` for NEAR. Refuses unless `keypair` is
/// ML-DSA-65 *and* is the key the transaction declares. Returns
/// `signature ‖ public_key` (3309 + 1952 bytes).
#[flutter_rust_bridge::frb(sync)]
pub fn sign_near_transaction(
    keypair: &Keypair,
    transaction: Vec<u8>,
    entropy: Option<[u8; 32]>,
) -> Result<Vec<u8>, String> {
    require_ml_dsa_65(keypair)?;
    let wire = decode_wire(&transaction)?;
    if wire.public_key.bytes() != keypair.public_key {
        return Err(format!(
            "Transaction is signed by {}, not by this account",
            wire.public_key.text()
        ));
    }

    let secret = ml_dsa_65::SecretKey::from_bytes(&keypair.secret_key)
        .map_err(|e| format!("Secret key does not parse: {e:?}"))?;
    let mut entropy = entropy;
    let hedge = entropy.as_mut().map(SensitiveBytes32::new);
    let hash = Sha256::digest(&transaction);
    // Pure ML-DSA, no context: NEAR's verifier passes none.
    let signature = secret
        .sign(&hash, None, hedge.as_ref())
        .map_err(|e| format!("Signing failed: {e:?}"))?;

    let mut response = Vec::with_capacity(ML_DSA_65_SIGNATURE_LEN + ML_DSA_65_PUBLIC_KEY_LEN);
    response.extend_from_slice(signature.as_ref());
    response.extend_from_slice(&keypair.public_key);
    Ok(response)
}

/// Whether `signature` is a valid pure ML-DSA-65 signature by `public_key`
/// over the transaction, as the NEAR runtime checks it.
#[flutter_rust_bridge::frb(sync)]
pub fn verify_near_signature(
    public_key: Vec<u8>,
    transaction: Vec<u8>,
    signature: Vec<u8>,
) -> bool {
    let Ok(public) = ml_dsa_65::PublicKey::from_bytes(&public_key) else {
        return false;
    };
    public.verify(&Sha256::digest(&transaction), &signature, None)
}

/// The account's key in NEAR text form, `ml-dsa-65:<base58>`. This is the
/// `--signer-public-key` near-cli-rs takes and what an `AddKey` carries.
#[flutter_rust_bridge::frb(sync)]
pub fn near_public_key_text(keypair: &Keypair) -> Result<String, String> {
    require_ml_dsa_65(keypair)?;
    Ok(format!(
        "ml-dsa-65:{}",
        bs58::encode(&keypair.public_key).into_string()
    ))
}

/// The on-chain handle of the key, `ml-dsa-65-hash:<base58>`: what
/// `view_access_key_list` shows, SHA3-256 of a domain tag and the key.
#[flutter_rust_bridge::frb(sync)]
pub fn near_public_key_handle(keypair: &Keypair) -> Result<String, String> {
    require_ml_dsa_65(keypair)?;
    let mut hasher = Sha3_256::new();
    hasher.update(ML_DSA_65_HANDLE_DOMAIN_TAG);
    hasher.update(&keypair.public_key);
    Ok(format!(
        "ml-dsa-65-hash:{}",
        bs58::encode(hasher.finalize()).into_string()
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::crypto::generate_keypair_from_seed;

    /// near-cli-rs 0.30.1 `sign-later` output for a 1 NEAR transfer
    /// alice.testnet → bob.testnet, ed25519 key 0x11×32, nonce 42, block hash
    /// 0x22×32. The same vector pins quantus-cli's encoder.
    const NEAR_CLI_UNSIGNED_B64: &str = "DQAAAGFsaWNlLnRlc3RuZXQAEREREREREREREREREREREREREREREREREREREREREREqAAAAAAAAAAsAAABib2IudGVzdG5ldCIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiAQAAAAMAAACh7czOG8LTAAAAAAAA";
    const NEAR_CLI_HASH_HEX: &str =
        "be358ec90e89b70256db586f72c4a280daa1199ba6f91398e9d034b72a7a6c9f";

    fn b64(s: &str) -> Vec<u8> {
        // Minimal base64 decoder: keeps the test free of a new dependency.
        const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let mut out = Vec::new();
        let mut buf = 0u32;
        let mut bits = 0;
        for &c in s.as_bytes() {
            if c == b'=' {
                break;
            }
            let v = ALPHABET.iter().position(|&a| a == c).expect("base64 char") as u32;
            buf = (buf << 6) | v;
            bits += 6;
            if bits >= 8 {
                bits -= 8;
                out.push((buf >> bits) as u8);
                buf &= (1 << bits) - 1;
            }
        }
        out
    }

    fn ml_dsa_65_keypair(seed: u8) -> Keypair {
        let mut seed = [seed; 32];
        let mut entropy = SensitiveBytes32::new(&mut seed);
        let keypair = ml_dsa_65::Keypair::generate(&mut entropy);
        Keypair {
            public_key: keypair.public().to_bytes().to_vec(),
            secret_key: keypair.secret().to_bytes().to_vec(),
            scheme: DilithiumScheme::MlDsa65,
        }
    }

    fn tx_for(keypair: &Keypair) -> Vec<u8> {
        let key: [u8; ML_DSA_65_PUBLIC_KEY_LEN] = keypair.public_key.as_slice().try_into().unwrap();
        borsh::to_vec(&WireTransaction {
            signer_id: "vault.alice.near".to_string(),
            public_key: WirePublicKey::MlDsa65(Box::new(key)),
            nonce: 101,
            receiver_id: "v2.ref-finance.near".to_string(),
            block_hash: [0x22; 32],
            actions: vec![WireAction::FunctionCall {
                method_name: "storage_deposit".to_string(),
                args: br#"{"registration_only":true}"#.to_vec(),
                gas: 30_000_000_000_000,
                deposit: 125 * 10u128.pow(21),
            }],
        })
        .unwrap()
    }

    #[test]
    fn decodes_near_cli_sign_later_output() {
        let bytes = b64(NEAR_CLI_UNSIGNED_B64);
        let tx = decode_near_transaction(bytes.clone()).unwrap();
        assert_eq!(tx.signer_id, "alice.testnet");
        assert_eq!(tx.receiver_id, "bob.testnet");
        assert_eq!(tx.nonce, 42);
        assert_eq!(
            tx.public_key,
            "ed25519:29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2"
        );
        assert_eq!(tx.public_key_bytes, vec![0x11; 32]);
        assert!(!tx.signs_with_ml_dsa_65);
        assert_eq!(
            tx.block_hash,
            "3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3"
        );
        assert_eq!(hex::encode(&tx.hash), NEAR_CLI_HASH_HEX);
        assert_eq!(
            tx.actions,
            vec![NearAction {
                kind: NearActionKind::Transfer,
                amount: Some(10u128.pow(24)),
                ..Default::default()
            }]
        );
        assert_eq!(near_transaction_hash(bytes), tx.hash);
    }

    #[test]
    fn rejects_account_ids_the_chain_would_refuse() {
        for good in ["alice.testnet", "a1", "sub.a-b_c.near", &"a".repeat(64)] {
            assert!(check_account_id("t", good).is_ok(), "{good}");
        }
        for bad in [
            "a",
            "Alice.testnet",
            "alice..testnet",
            ".alice",
            "alice.",
            "-alice",
            "alice-",
            "ali--ce",
            "ali_-ce",
            "alice\u{202E}testnet",
            "alice testnet",
            &"a".repeat(65),
        ] {
            assert!(check_account_id("t", bad).is_err(), "{bad:?}");
        }

        let mut bytes = b64(NEAR_CLI_UNSIGNED_B64);
        // Flip the first byte of "alice.testnet" to an uppercase 'A'.
        bytes[4] = b'A';
        let err = decode_near_transaction(bytes).unwrap_err();
        assert!(err.contains("signer"), "{err}");
    }

    #[test]
    fn rejects_trailing_and_truncated_bytes() {
        let bytes = b64(NEAR_CLI_UNSIGNED_B64);
        let mut extended = bytes.clone();
        extended.push(0);
        assert!(decode_near_transaction(extended).is_err());
        assert!(decode_near_transaction(bytes[..bytes.len() - 1].to_vec()).is_err());
        assert!(decode_near_transaction(Vec::new()).is_err());
    }

    #[test]
    fn decodes_every_action_kind() {
        let key = WirePublicKey::MlDsa65(Box::new([0x33; ML_DSA_65_PUBLIC_KEY_LEN]));
        let ed = WirePublicKey::Ed25519([0x11; 32]);
        let bytes = borsh::to_vec(&WireTransaction {
            signer_id: "a.near".to_string(),
            public_key: key.clone(),
            nonce: 1,
            receiver_id: "b.near".to_string(),
            block_hash: [0; 32],
            actions: vec![
                WireAction::CreateAccount,
                WireAction::DeployContract { code: vec![0; 10] },
                WireAction::Transfer { deposit: 5 },
                WireAction::Stake {
                    stake: 7,
                    public_key: ed.clone(),
                },
                WireAction::AddKey {
                    public_key: key.clone(),
                    access_key: WireAccessKey {
                        nonce: 0,
                        permission: WireAccessKeyPermission::FullAccess,
                    },
                },
                WireAction::AddKey {
                    public_key: ed.clone(),
                    access_key: WireAccessKey {
                        nonce: 0,
                        permission: WireAccessKeyPermission::FunctionCall(
                            WireFunctionCallPermission {
                                allowance: Some(250),
                                receiver_id: "c.near".to_string(),
                                method_names: vec!["ping".to_string()],
                            },
                        ),
                    },
                },
                WireAction::DeleteKey {
                    public_key: ed.clone(),
                },
                WireAction::DeleteAccount {
                    beneficiary_id: "d.near".to_string(),
                },
            ],
        })
        .unwrap();

        let tx = decode_near_transaction(bytes).unwrap();
        assert!(tx.signs_with_ml_dsa_65);
        assert!(tx.public_key.starts_with("ml-dsa-65:"));
        assert_eq!(tx.actions.len(), 8);
        let kinds: Vec<NearActionKind> = tx.actions.iter().map(|a| a.kind).collect();
        assert_eq!(
            kinds,
            vec![
                NearActionKind::CreateAccount,
                NearActionKind::DeployContract,
                NearActionKind::Transfer,
                NearActionKind::Stake,
                NearActionKind::AddKey,
                NearActionKind::AddKey,
                NearActionKind::DeleteKey,
                NearActionKind::DeleteAccount,
            ]
        );
        assert_eq!(tx.actions[1].code_len, Some(10));
        assert_eq!(tx.actions[2].amount, Some(5));
        assert_eq!(
            (tx.actions[3].amount, tx.actions[3].public_key.as_deref()),
            (Some(7), Some(ed.text().as_str()))
        );
        assert_eq!(
            tx.actions[4],
            NearAction {
                kind: NearActionKind::AddKey,
                public_key: Some(key.text()),
                full_access: true,
                ..Default::default()
            }
        );
        assert_eq!(
            tx.actions[5],
            NearAction {
                kind: NearActionKind::AddKey,
                public_key: Some(ed.text()),
                full_access: false,
                target: Some("c.near".to_string()),
                amount: Some(250),
                method_names: vec!["ping".to_string()],
                ..Default::default()
            }
        );
        assert_eq!(tx.actions[6].public_key, Some(ed.text()));
        assert_eq!(tx.actions[7].target, Some("d.near".to_string()));
    }

    #[test]
    fn function_call_action_carries_method_args_gas_and_deposit() {
        let keypair = ml_dsa_65_keypair(7);
        let tx = decode_near_transaction(tx_for(&keypair)).unwrap();
        assert_eq!(tx.signer_id, "vault.alice.near");
        assert_eq!(tx.receiver_id, "v2.ref-finance.near");
        assert_eq!(tx.public_key_bytes, keypair.public_key);
        assert!(tx.signs_with_ml_dsa_65);
        assert_eq!(
            tx.actions,
            vec![NearAction {
                kind: NearActionKind::FunctionCall,
                target: Some("storage_deposit".to_string()),
                args: Some(br#"{"registration_only":true}"#.to_vec()),
                gas: Some(30_000_000_000_000),
                amount: Some(125 * 10u128.pow(21)),
                ..Default::default()
            }]
        );
    }

    #[test]
    fn signs_pure_ml_dsa_65_over_the_hash_and_appends_the_key() {
        let keypair = ml_dsa_65_keypair(7);
        let tx = tx_for(&keypair);

        let response = sign_near_transaction(&keypair, tx.clone(), Some([9; 32])).unwrap();
        assert_eq!(
            response.len(),
            ML_DSA_65_SIGNATURE_LEN + ML_DSA_65_PUBLIC_KEY_LEN
        );
        let (signature, public) = response.split_at(ML_DSA_65_SIGNATURE_LEN);
        assert_eq!(public, keypair.public_key.as_slice());

        assert!(verify_near_signature(
            public.to_vec(),
            tx.clone(),
            signature.to_vec()
        ));

        // Pure signature: verifies with no context and fails under the
        // Quantus extrinsic context.
        let verifier = ml_dsa_65::PublicKey::from_bytes(public).unwrap();
        let hash = Sha256::digest(&tx);
        assert!(verifier.verify(&hash, signature, None));
        assert!(!verifier.verify(&hash, signature, Some(crate::signing_context::EXTRINSIC)));

        // Bound to this exact transaction.
        let mut other = tx.clone();
        let nonce_offset = 4 + "vault.alice.near".len() + 1 + ML_DSA_65_PUBLIC_KEY_LEN;
        other[nonce_offset] ^= 1;
        assert!(!verify_near_signature(
            public.to_vec(),
            other,
            signature.to_vec()
        ));

        // Deterministic signing (no hedge) is also accepted.
        let det = sign_near_transaction(&keypair, tx.clone(), None).unwrap();
        assert!(verify_near_signature(
            keypair.public_key.clone(),
            tx,
            det[..ML_DSA_65_SIGNATURE_LEN].to_vec()
        ));
    }

    #[test]
    fn refuses_other_keys_and_ml_dsa_87_accounts() {
        let keypair = ml_dsa_65_keypair(7);
        let other = ml_dsa_65_keypair(8);
        let tx = tx_for(&keypair);

        let err = sign_near_transaction(&other, tx.clone(), None).unwrap_err();
        assert!(err.contains("not by this account"), "{err}");

        let ml87 = generate_keypair_from_seed(vec![1; 32]);
        assert_eq!(ml87.scheme, DilithiumScheme::MlDsa87);
        let err = sign_near_transaction(&ml87, tx, None).unwrap_err();
        assert!(err.contains("ML-DSA-65"), "{err}");
        assert!(near_public_key_text(&ml87).is_err());
        assert!(near_public_key_handle(&ml87).is_err());
    }

    #[test]
    fn key_text_and_handle_match_nearcore() {
        let mut keypair = ml_dsa_65_keypair(7);
        keypair.public_key = vec![0x42; ML_DSA_65_PUBLIC_KEY_LEN];

        let text = near_public_key_text(&keypair).unwrap();
        assert!(text.starts_with("ml-dsa-65:"));
        assert_eq!(
            bs58::decode(&text["ml-dsa-65:".len()..])
                .into_vec()
                .unwrap(),
            keypair.public_key
        );

        // Golden from quantus-cli (SHA3-256 over tag ‖ key), cross-checked
        // against near-cli-rs's "pub key hash" display.
        let handle = near_public_key_handle(&keypair).unwrap();
        let handle_bytes = bs58::decode(&handle["ml-dsa-65-hash:".len()..])
            .into_vec()
            .unwrap();
        assert_eq!(
            hex::encode(handle_bytes),
            "0ef8ccba4bb1a8859f1cc3d17c4d9d35712b8ddedd3875906559c50f7dd86505"
        );
    }
}
