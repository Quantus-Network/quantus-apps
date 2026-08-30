use parity_scale_codec::{Decode, DecodeLimit, Error as CodecError, Input};
use std::fmt;

/// Hard cap on the raw signing payload. Sized so a chain-maximum proposal still fits:
/// `MAX_CALL_BYTES` of inner call, plus the multisig wrapper and the signed extensions.
const MAX_PAYLOAD_BYTES: usize = 12 * 1024;
/// Maximum nesting of multisig `propose` inner calls (top-level call is depth 0).
const MAX_CALL_DEPTH: u32 = 2;
/// Largest inner call a multisig proposal may carry, mirroring the runtime's
/// `pallet_multisig::Config::MaxCallSize` (`BoundedVec<u8, MaxCallSize>`, 10 KiB).
///
/// Deliberately the chain's number rather than a tighter one of our own: a limit below it
/// would refuse proposals the chain accepts, leaving a multisig no cold signer could act on.
const MAX_CALL_BYTES: usize = 10 * 1024;
/// A chain-maximum proposal has to fit in a payload, or the cap above is unreachable.
const _: () = assert!(MAX_PAYLOAD_BYTES > MAX_CALL_BYTES + 256);

/// Networks this parser will accept: (genesis hash, display name).
/// A payload whose `CheckGenesis` hash is not listed here is rejected.
const KNOWN_NETWORKS: &[([u8; 32], &str)] = &[
    (
        // Planck: 0x4901bf5c57fd3f9e726af399c763de6670dbdb115a91c0237e173f16eef65e72
        [
            0x49, 0x01, 0xbf, 0x5c, 0x57, 0xfd, 0x3f, 0x9e, 0x72, 0x6a, 0xf3, 0x99, 0xc7, 0x63,
            0xde, 0x66, 0x70, 0xdb, 0xdb, 0x11, 0x5a, 0x91, 0xc0, 0x23, 0x7e, 0x17, 0x3f, 0x16,
            0xee, 0xf6, 0x5e, 0x72,
        ],
        "Planck",
    ),
    (
        // Heisenberg: 0xa5aa9e5c84d4a3722c152295e7973c9af522f2fb1ef7db5afaa3d5f4dc8d3b4f
        [
            0xa5, 0xaa, 0x9e, 0x5c, 0x84, 0xd4, 0xa3, 0x72, 0x2c, 0x15, 0x22, 0x95, 0xe7, 0x97,
            0x3c, 0x9a, 0xf5, 0x22, 0xf2, 0xfb, 0x1e, 0xf7, 0xdb, 0x5a, 0xfa, 0xa3, 0xd5, 0xf4,
            0xdc, 0x8d, 0x3b, 0x4f,
        ],
        "Heisenberg",
    ),
];

// Mirrors of the on-chain call types, decoded with the same SCALE derive the runtime uses.
// `#[codec(index)]` must match the runtime pallet/call indices and `#[codec(compact)]` must
// match `#[pallet::compact]` in the pallet declarations (chain `main`, spec >= 147).
// Any pallet, call, or variant not declared here hard-fails decoding.

#[derive(Decode)]
enum MultiAddress {
    #[codec(index = 0)]
    Id([u8; 32]),
}

#[derive(Decode)]
enum BalancesCall {
    #[codec(index = 0)]
    TransferAllowDeath {
        dest: MultiAddress,
        #[codec(compact)]
        value: u128,
    },
    #[codec(index = 3)]
    TransferKeepAlive {
        dest: MultiAddress,
        #[codec(compact)]
        value: u128,
    },
}

// qp_scheduler::BlockNumberOrTimestamp<u32, u64>
#[derive(Decode)]
enum BlockNumberOrTimestamp {
    #[codec(index = 0)]
    BlockNumber(u32),
    #[codec(index = 1)]
    Timestamp(u64),
}

#[derive(Decode)]
enum ReversibleTransfersCall {
    #[codec(index = 3)]
    ScheduleTransfer { dest: MultiAddress, amount: u128 },
    #[codec(index = 4)]
    ScheduleTransferWithDelay {
        dest: MultiAddress,
        amount: u128,
        delay: BlockNumberOrTimestamp,
    },
}

#[derive(Decode)]
enum MultisigCall {
    #[codec(index = 0)]
    CreateMultisig {
        signers: Vec<[u8; 32]>,
        threshold: u32,
        nonce: u64,
    },
    #[codec(index = 1)]
    Propose {
        multisig_address: [u8; 32],
        call: Vec<u8>,
        expiry: u32,
    },
    #[codec(index = 2)]
    Approve {
        multisig_address: [u8; 32],
        proposal_id: u32,
        call: Vec<u8>,
    },
    #[codec(index = 6)]
    Execute {
        multisig_address: [u8; 32],
        proposal_id: u32,
        // Inline `Box<RuntimeCall>`, not the length-prefixed bytes `approve` carries.
        call: Box<RuntimeCall>,
    },
}

#[derive(Decode)]
enum RuntimeCall {
    #[codec(index = 2)]
    Balances(BalancesCall),
    #[codec(index = 11)]
    ReversibleTransfers(ReversibleTransfersCall),
    #[codec(index = 19)]
    Multisig(MultisigCall),
}

/// sp_runtime `Era` (immortal = one zero byte, mortal = two bytes encoding period/phase).
#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Era {
    Immortal,
    Mortal { period: u64, phase: u64 },
}

impl Decode for Era {
    fn decode<I: Input>(input: &mut I) -> Result<Self, CodecError> {
        let first = input.read_byte()?;
        if first == 0 {
            return Ok(Era::Immortal);
        }
        let encoded = first as u64 + ((input.read_byte()? as u64) << 8);
        let period = 2u64 << (encoded % (1 << 4));
        let quantize_factor = (period >> 12).max(1);
        let phase = (encoded >> 4) * quantize_factor;
        if period >= 4 && phase < period {
            Ok(Era::Mortal { period, phase })
        } else {
            Err("invalid era period/phase".into())
        }
    }
}

impl fmt::Display for Era {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Era::Immortal => write!(f, "Immortal"),
            Era::Mortal { period, .. } => write!(f, "{} blocks", period),
        }
    }
}

#[derive(Decode, Debug, PartialEq)]
enum MetadataHashMode {
    #[codec(index = 0)]
    Disabled,
    #[codec(index = 1)]
    Enabled,
}

/// The runtime `TxExtension` data that follows the call in a signing payload, in declaration
/// order: explicit parts (era, nonce, tip, metadata-hash mode) then the implicit
/// "additional signed" parts (spec/tx version, genesis + block hash, optional metadata hash).
/// Extensions with unit encoding (CheckNonZeroSender, CheckWeight, Reversible, Wormhole)
/// contribute no bytes.
#[derive(Decode, Debug)]
pub struct SignedExtensions {
    pub era: Era,
    #[codec(compact)]
    pub nonce: u32,
    #[codec(compact)]
    pub tip: u128,
    metadata_mode: MetadataHashMode,
    pub spec_version: u32,
    pub transaction_version: u32,
    pub genesis_hash: [u8; 32],
    pub block_hash: [u8; 32],
    metadata_hash: Option<[u8; 32]>,
}

/// A decoded Quantus call. Display-only: the signer never blind-signs, it shows what it parses.
#[derive(Debug, PartialEq)]
pub enum QuantusTx {
    Transfer {
        to: String,
        amount: u128,
        is_reversible: bool,
        reversible_timeframe: Option<u64>,
    },
    MultisigCreate {
        signers: Vec<String>,
        threshold: u32,
        nonce: u64,
    },
    MultisigPropose {
        multisig: String,
        expiry: u32,
        inner: Box<QuantusTx>,
    },
    MultisigApprove {
        multisig: String,
        proposal_id: u32,
        inner: Box<QuantusTx>,
    },
    MultisigExecute {
        multisig: String,
        proposal_id: u32,
        inner: Box<QuantusTx>,
    },
}

impl QuantusTx {
    pub fn is_transfer(&self) -> bool {
        matches!(self, QuantusTx::Transfer { .. })
    }

    fn from_call(call: RuntimeCall, depth: u32) -> Result<Self, String> {
        match call {
            RuntimeCall::Balances(
                BalancesCall::TransferAllowDeath { dest, value }
                | BalancesCall::TransferKeepAlive { dest, value },
            ) => Ok(QuantusTx::Transfer {
                to: multi_address_to_ss58(dest),
                amount: value,
                is_reversible: false,
                reversible_timeframe: None,
            }),
            RuntimeCall::ReversibleTransfers(ReversibleTransfersCall::ScheduleTransfer {
                dest,
                amount,
            }) => Ok(QuantusTx::Transfer {
                to: multi_address_to_ss58(dest),
                amount,
                is_reversible: true,
                reversible_timeframe: None, // Uses configured delay
            }),
            RuntimeCall::ReversibleTransfers(
                ReversibleTransfersCall::ScheduleTransferWithDelay { dest, amount, delay },
            ) => {
                let delay_ms = match delay {
                    BlockNumberOrTimestamp::Timestamp(ms) => ms,
                    BlockNumberOrTimestamp::BlockNumber(n) => {
                        return Err(format!(
                            "Block-number delays are not supported (got block {})",
                            n
                        ))
                    }
                };
                Ok(QuantusTx::Transfer {
                    to: multi_address_to_ss58(dest),
                    amount,
                    is_reversible: true,
                    reversible_timeframe: Some(delay_ms),
                })
            }
            RuntimeCall::Multisig(MultisigCall::CreateMultisig {
                signers,
                threshold,
                nonce,
            }) => Ok(QuantusTx::MultisigCreate {
                signers: signers.iter().map(bytes_to_ss58).collect(),
                threshold,
                nonce,
            }),
            RuntimeCall::Multisig(MultisigCall::Propose {
                multisig_address,
                call,
                expiry,
            }) => {
                let inner = decode_call(&call, nested_depth(depth)?)?;
                Ok(QuantusTx::MultisigPropose {
                    multisig: bytes_to_ss58(&multisig_address),
                    expiry,
                    inner: Box::new(inner),
                })
            }
            RuntimeCall::Multisig(MultisigCall::Approve {
                multisig_address,
                proposal_id,
                call,
            }) => {
                let inner = decode_call(&call, nested_depth(depth)?)?;
                Ok(QuantusTx::MultisigApprove {
                    multisig: bytes_to_ss58(&multisig_address),
                    proposal_id,
                    inner: Box::new(inner),
                })
            }
            RuntimeCall::Multisig(MultisigCall::Execute {
                multisig_address,
                proposal_id,
                call,
            }) => {
                let inner = QuantusTx::from_call(*call, nested_depth(depth)?)?;
                Ok(QuantusTx::MultisigExecute {
                    multisig: bytes_to_ss58(&multisig_address),
                    proposal_id,
                    inner: Box::new(inner),
                })
            }
        }
    }
}

impl fmt::Display for QuantusTx {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            QuantusTx::Transfer { to, amount, is_reversible, reversible_timeframe } => {
                let amount_f64 = *amount as f64 / 1_000_000_000_000.0;
                write!(f, "Transfer to {} amount {:.4} reversible {}", to, amount_f64, is_reversible)?;
                if let Some(t) = reversible_timeframe {
                    write!(f, " timeframe {}ms", t)?;
                }
                Ok(())
            }
            QuantusTx::MultisigCreate { signers, threshold, nonce } => {
                write!(f, "Create multisig {} of {} nonce {}", threshold, signers.len(), nonce)
            }
            QuantusTx::MultisigPropose { multisig, expiry, inner } => {
                write!(f, "Multisig propose on {} expiry {} call [{}]", multisig, expiry, inner)
            }
            QuantusTx::MultisigApprove { multisig, proposal_id, inner } => {
                write!(f, "Multisig approve on {} proposal {} call [{}]", multisig, proposal_id, inner)
            }
            QuantusTx::MultisigExecute { multisig, proposal_id, inner } => {
                write!(f, "Multisig execute on {} proposal {} call [{}]", multisig, proposal_id, inner)
            }
        }
    }
}

/// A fully decoded signing payload: the call plus every signed-extension field, with no
/// bytes left over. Everything that gets signed is either displayed or validated.
#[derive(Debug)]
pub struct ParsedPayload {
    pub call: QuantusTx,
    pub extensions: SignedExtensions,
    pub network: &'static str,
}

impl fmt::Display for ParsedPayload {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}\nNetwork: {}\nEra: {}\nNonce: {}\nTip: {:.4}",
            self.call,
            self.network,
            self.extensions.era,
            self.extensions.nonce,
            self.extensions.tip as f64 / 1_000_000_000_000.0,
        )
    }
}

pub fn bytes_to_ss58(bytes: &[u8; 32]) -> String {
    const SS58_PREFIX: u16 = 189; // Quantus SS58 prefix
    ss58::encode(bytes, ss58::Ss58AddressFormat::Custom(SS58_PREFIX))
}

fn multi_address_to_ss58(address: MultiAddress) -> String {
    let MultiAddress::Id(account_id) = address;
    bytes_to_ss58(&account_id)
}

fn check_call_size(len: usize) -> Result<(), String> {
    if len > MAX_CALL_BYTES {
        return Err(format!(
            "Call is {} bytes, over the {} byte review limit",
            len, MAX_CALL_BYTES
        ));
    }
    Ok(())
}

/// Depth of the next nested call, or an error once `MAX_CALL_DEPTH` is reached.
fn nested_depth(depth: u32) -> Result<u32, String> {
    if depth >= MAX_CALL_DEPTH {
        return Err(format!(
            "Multisig call nesting exceeds depth limit {}",
            MAX_CALL_DEPTH
        ));
    }
    Ok(depth + 1)
}

/// `execute` nests inline, so the codec recurses before `MAX_CALL_DEPTH` can be checked.
/// The deepest legitimate payload descends 3 (`execute` -> `execute` -> a `Vec` field).
const MAX_DECODE_DEPTH: u32 = 4;

fn decode_runtime_call<I: Input>(input: &mut I) -> Result<RuntimeCall, String> {
    RuntimeCall::decode_with_depth_limit(MAX_DECODE_DEPTH, input).map_err(|e| format!("call: {}", e))
}

fn decode_call(bytes: &[u8], depth: u32) -> Result<QuantusTx, String> {
    check_call_size(bytes.len())?;
    let mut input = bytes;
    let call = decode_runtime_call(&mut input)?;
    if !input.is_empty() {
        return Err(format!("{} trailing bytes after call", input.len()));
    }
    QuantusTx::from_call(call, depth)
}

pub fn parse_payload(payload: &[u8]) -> Result<ParsedPayload, String> {
    if payload.len() > MAX_PAYLOAD_BYTES {
        return Err(format!("Payload too large: {} bytes", payload.len()));
    }

    let mut input = payload;
    let call = decode_runtime_call(&mut input)?;
    let extensions =
        SignedExtensions::decode(&mut input).map_err(|e| format!("extensions: {}", e))?;
    if !input.is_empty() {
        return Err(format!("{} trailing bytes after signed payload", input.len()));
    }

    match (&extensions.metadata_mode, extensions.metadata_hash.is_some()) {
        (MetadataHashMode::Disabled, false) | (MetadataHashMode::Enabled, true) => {}
        (mode, _) => {
            return Err(format!(
                "Metadata hash mode {:?} inconsistent with metadata hash presence",
                mode
            ))
        }
    }

    let network = KNOWN_NETWORKS
        .iter()
        .find(|(genesis, _)| *genesis == extensions.genesis_hash)
        .map(|(_, name)| *name)
        .ok_or_else(|| {
            format!("Unknown genesis hash: {}", hex::encode(extensions.genesis_hash))
        })?;

    let call = QuantusTx::from_call(call, 0)?;
    Ok(ParsedPayload { call, extensions, network })
}

#[cfg(test)]
mod tests {
    use super::*;
    use hex;
    use parity_scale_codec::{Compact, Encode};

    const PLANCK_GENESIS: [u8; 32] = KNOWN_NETWORKS[0].0;

    // Call portions of the original "real world" vectors (extensions stripped); the full
    // vectors were captured on a retired devnet whose genesis hash is no longer accepted.
    // The reversible call is re-indexed from the retired pallet index 13 to the current 11.
    const TRANSFER_CALL_1: &str =
        "020000ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb40700282e8cd1";
    const TRANSFER_CALL_2: &str =
        "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e8764817";
    const REVERSIBLE_CALL: &str =
        "0b04007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0040b0464f010000000000000000000001e093040000000000";

    // The two original real-world vectors, kept verbatim as regression tests: both were
    // captured on the retired devnet (genesis 826beefb…) and must now be rejected.
    const OLD_NETWORK_TRANSFER: &str =
        "020000ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb40700282e8cd185012800007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e3d3e081c6e3599f8ae31d404d9f087f50c25b4e08c35712e23470a60da5799ca00";
    const OLD_NETWORK_REVERSIBLE: &str =
        "0d04007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0040b0464f010000000000000000000001e093040000000000d5010c00007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118efeebb9b31159a679a1e49ccc34d363b5d4a00b836ad4f85cbba8c6274ac2566800";

    fn ext_suffix(era: &[u8], nonce: u32, tip: u128, genesis: &[u8; 32]) -> Vec<u8> {
        let mut v = Vec::new();
        v.extend_from_slice(era);
        v.extend(Compact(nonce).encode());
        v.extend(Compact(tip).encode());
        v.push(0); // metadata hash mode: disabled
        v.extend_from_slice(&131u32.to_le_bytes()); // spec_version
        v.extend_from_slice(&2u32.to_le_bytes()); // transaction_version
        v.extend_from_slice(genesis);
        v.extend_from_slice(&[0x11; 32]); // block hash (not validated)
        v.push(0); // metadata hash: None
        v
    }

    fn payload_with_suffix(call_hex: &str, era: &[u8], nonce: u32, tip: u128) -> Vec<u8> {
        let mut payload = hex::decode(call_hex).unwrap();
        payload.extend(ext_suffix(era, nonce, tip, &PLANCK_GENESIS));
        payload
    }

    fn parse(payload: &[u8]) -> ParsedPayload {
        parse_payload(payload).unwrap()
    }

    fn assert_transfer(tx: &QuantusTx, address: &str, amount: u128, reversible: bool, timeframe: Option<u64>) {
        match tx {
            QuantusTx::Transfer { to, amount: a, is_reversible, reversible_timeframe } => {
                assert_eq!(to, address);
                assert_eq!(*a, amount);
                assert_eq!(*is_reversible, reversible);
                assert_eq!(*reversible_timeframe, timeframe);
            }
            other => panic!("expected Transfer, got {:?}", other),
        }
    }

    #[test]
    fn test_parse_transfer_with_extensions() {
        // Mortal era bytes 8501 = period 64 phase 24; compact nonce 10.
        let payload = payload_with_suffix(TRANSFER_CALL_1, &[0x85, 0x01], 10, 0);
        let parsed = parse(&payload);
        assert_transfer(
            &parsed.call,
            "qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86",
            900000000000u128,
            false,
            None,
        );
        assert_eq!(parsed.extensions.era, Era::Mortal { period: 64, phase: 24 });
        assert_eq!(parsed.extensions.nonce, 10);
        assert_eq!(parsed.extensions.tip, 0);
        assert_eq!(parsed.extensions.spec_version, 131);
        assert_eq!(parsed.extensions.transaction_version, 2);
        assert_eq!(parsed.network, "Planck");
    }

    #[test]
    fn test_parse_transfer_with_tip_and_immortal_era() {
        let tip = 1_500_000_000_000u128;
        let payload = payload_with_suffix(TRANSFER_CALL_2, &[0x00], 0, tip);
        let parsed = parse(&payload);
        assert_transfer(
            &parsed.call,
            "qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG",
            100000000000u128,
            false,
            None,
        );
        assert_eq!(parsed.extensions.era, Era::Immortal);
        assert_eq!(parsed.extensions.tip, tip);
    }

    #[test]
    fn test_parse_reversible_transfer_with_delay() {
        let payload = payload_with_suffix(REVERSIBLE_CALL, &[0x00], 3, 0);
        let parsed = parse(&payload);
        assert_transfer(
            &parsed.call,
            "qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG",
            1440000000000u128,
            true,
            Some(300000u64),
        );
        assert_eq!(parsed.extensions.nonce, 3);
    }

    #[test]
    fn test_reject_old_devnet_transfer_unknown_genesis() {
        // Proves the parser walks all the way to the genesis hash and rejects unknown networks.
        let payload = hex::decode(OLD_NETWORK_TRANSFER).unwrap();
        let err = parse_payload(&payload).unwrap_err();
        assert!(err.contains("Unknown genesis hash"), "{}", err);
    }

    #[test]
    fn test_reject_old_devnet_reversible_transfer() {
        // Rejected at call decode: ReversibleTransfers moved from pallet index 13 to 11 when
        // the devnet was retired, so this never reaches the (equally retired) genesis hash.
        let payload = hex::decode(OLD_NETWORK_REVERSIBLE).unwrap();
        let err = parse_payload(&payload).unwrap_err();
        assert!(err.contains("call"), "{}", err);
    }

    #[test]
    fn test_reject_trailing_bytes() {
        let mut payload = payload_with_suffix(TRANSFER_CALL_1, &[0x85, 0x01], 10, 0);
        payload.extend_from_slice(&[0xde, 0xad, 0xbe, 0xef]);
        let err = parse_payload(&payload).unwrap_err();
        assert!(err.contains("trailing bytes"), "{}", err);
    }

    #[test]
    fn test_reject_bare_call_without_extensions() {
        let payload = hex::decode(TRANSFER_CALL_1).unwrap();
        assert!(parse_payload(&payload).is_err());
    }

    #[test]
    fn test_reject_metadata_mode_mismatch() {
        let mut payload = hex::decode(TRANSFER_CALL_1).unwrap();
        let mut suffix = ext_suffix(&[0x00], 0, 0, &PLANCK_GENESIS);
        suffix[3] = 1; // mode: enabled, but metadata hash stays None
        payload.extend(suffix);
        let err = parse_payload(&payload).unwrap_err();
        assert!(err.contains("inconsistent"), "{}", err);
    }

    #[test]
    fn test_reject_oversized_payload() {
        let payload = vec![0u8; MAX_PAYLOAD_BYTES + 1];
        let err = parse_payload(&payload).unwrap_err();
        assert!(err.contains("too large"), "{}", err);
    }

    #[test]
    fn test_reject_unknown_pallet_and_call() {
        assert!(parse_payload(&payload_with_suffix("0500", &[0x00], 0, 0)).is_err());
        assert!(parse_payload(&payload_with_suffix("0202", &[0x00], 0, 0)).is_err());
    }

    #[test]
    fn test_reject_huge_vec_length_prefix() {
        // create_multisig with a signers length prefix far beyond the input size
        let err = parse_payload(&payload_with_suffix("1300feffffff", &[0x00], 0, 0)).unwrap_err();
        assert!(err.contains("call"), "{}", err);
    }

    // Authoritative multisig vectors: SCALE-encoded offline from the live chain
    // metadata via subxt (quantus-cli example `encode_multisig_vectors`).
    // SS58 strings below are sp_core-encoded (network 189) and cross-check the ss58 crate.
    const SS58_A: &str = "qzoK1UVQSssYHuTWxAN1U8egoJWRjTzF1LBcRubYp5a19ium3";
    const SS58_B: &str = "qzohPMkqjuMjQajDBZCU52NqZUjuMQLHSYWiSR3PhWZSegGEF";
    const SS58_C: &str = "qzp5mF2H2vqvXFzuQx2vfv6zKeyNyLgKskqpSvVEawYt9dJPY";
    const SS58_MULTISIG: &str = "qznvdbDy9rPMBEBpimXYsEvY38Gx7XeCa7rWRQ9hveaZemr8U";
    const SS58_DEST: &str = "qzn9sph6ZoQxwseSFyrdfTUEWmozsex7hhCJQPG29nbgesGei";

    fn parse_call_hex(call_hex: &str) -> QuantusTx {
        parse(&payload_with_suffix(call_hex, &[0x00], 0, 0)).call
    }

    /// `create_multisig` with `signers` accounts: the cheapest way to build a call of a
    /// chosen size out of calls the parser actually supports.
    fn create_multisig_call(signers: usize) -> Vec<u8> {
        let mut call = vec![0x13, 0x00];
        call.extend(Compact(signers as u32).encode());
        for _ in 0..signers {
            call.extend_from_slice(&[0xaa; 32]);
        }
        call.extend_from_slice(&2u32.to_le_bytes());
        call.extend_from_slice(&0u64.to_le_bytes());
        call
    }

    #[test]
    fn test_accepts_an_inner_call_at_the_chain_limit() {
        // A proposal the chain would accept must not be refused here: 319 signers encodes to
        // 10_224 bytes, just inside `MaxCallSize`, and the propose wrapper pushes the outer
        // call past it — which is why the limit is not applied to the outer call.
        let inner = create_multisig_call(319);
        assert!(inner.len() <= MAX_CALL_BYTES);
        let wrapped = propose_wrapping(&inner);
        assert!(wrapped.len() > MAX_CALL_BYTES);
        assert!(parse_wrapped(wrapped).is_ok());
    }

    #[test]
    fn test_reject_inner_call_over_the_chain_limit() {
        // 320 signers encodes to 10_256 bytes, just over `MaxCallSize`.
        let oversized = create_multisig_call(320);
        assert!(oversized.len() > MAX_CALL_BYTES);
        for wrapped in [propose_wrapping(&oversized), approve_wrapping(&oversized)] {
            let err = parse_wrapped(wrapped).unwrap_err();
            assert!(err.contains("review limit"), "{}", err);
        }
    }

    #[test]
    fn test_parse_real_multisig_create() {
        let tx = parse_call_hex("13000caaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc020000000000000000000000");
        match tx {
            QuantusTx::MultisigCreate { signers, threshold, nonce } => {
                assert_eq!(signers, [SS58_A, SS58_B, SS58_C]);
                assert_eq!(threshold, 2);
                assert_eq!(nonce, 0);
            }
            other => panic!("expected MultisigCreate, got {:?}", other),
        }
    }

    const INNER_TRANSFER: &str =
        "020000777777777777777777777777777777777777777777777777777777777777777707002465c709";

    /// `approve` binds to the proposal's call bytes: length-prefixed `BoundedVec<u8>`.
    fn approve_wrapping(inner: &[u8]) -> Vec<u8> {
        let mut call = vec![0x13, 0x02];
        call.extend_from_slice(&[0x99; 32]);
        call.extend_from_slice(&7u32.to_le_bytes());
        call.extend(Compact(inner.len() as u32).encode());
        call.extend_from_slice(inner);
        call
    }

    /// `execute` carries the call it dispatches inline, with no length prefix.
    fn execute_wrapping(inner: &[u8]) -> Vec<u8> {
        let mut call = vec![0x13, 0x06];
        call.extend_from_slice(&[0x99; 32]);
        call.extend_from_slice(&7u32.to_le_bytes());
        call.extend_from_slice(inner);
        call
    }

    fn parse_wrapped(wrapped: Vec<u8>) -> Result<ParsedPayload, String> {
        let mut payload = wrapped;
        payload.extend(ext_suffix(&[0x00], 0, 0, &PLANCK_GENESIS));
        parse_payload(&payload)
    }

    #[test]
    fn test_parse_real_multisig_approve() {
        let inner = hex::decode(INNER_TRANSFER).unwrap();
        match parse_wrapped(approve_wrapping(&inner)).unwrap().call {
            QuantusTx::MultisigApprove { multisig, proposal_id, inner } => {
                assert_eq!(multisig, SS58_MULTISIG);
                assert_eq!(proposal_id, 7);
                assert_transfer(&inner, SS58_DEST, 42_000_000_000u128, false, None);
            }
            other => panic!("expected MultisigApprove, got {:?}", other),
        }
    }

    #[test]
    fn test_parse_real_multisig_execute() {
        let inner = hex::decode(INNER_TRANSFER).unwrap();
        match parse_wrapped(execute_wrapping(&inner)).unwrap().call {
            QuantusTx::MultisigExecute { multisig, proposal_id, inner } => {
                assert_eq!(multisig, SS58_MULTISIG);
                assert_eq!(proposal_id, 7);
                assert_transfer(&inner, SS58_DEST, 42_000_000_000u128, false, None);
            }
            other => panic!("expected MultisigExecute, got {:?}", other),
        }
    }

    #[test]
    fn test_reject_multisig_execute_without_inner_call() {
        // The pre-PR-675 encoding carried no call; it must not parse.
        let mut call = vec![0x13, 0x06];
        call.extend_from_slice(&[0x99; 32]);
        call.extend_from_slice(&7u32.to_le_bytes());
        assert!(parse_wrapped(call).is_err());
    }

    #[test]
    fn test_reject_undecodable_inner_calls() {
        let bad = hex::decode("0500").unwrap();
        assert!(parse_wrapped(approve_wrapping(&bad)).is_err());
        assert!(parse_wrapped(execute_wrapping(&bad)).is_err());
    }

    #[test]
    fn test_multisig_execute_nesting_depth_limit() {
        let transfer = hex::decode(TRANSFER_CALL_1).unwrap();
        assert!(parse_wrapped(execute_wrapping(&execute_wrapping(&transfer))).is_ok());

        let err =
            parse_wrapped(execute_wrapping(&execute_wrapping(&execute_wrapping(&transfer)))).unwrap_err();
        assert!(err.contains("depth limit"), "{}", err);
    }

    #[test]
    fn test_execute_nesting_bomb_rejected_by_codec_depth_limit() {
        // Inline nesting recurses inside the codec, before any parser-level depth check.
        let mut call = hex::decode(TRANSFER_CALL_1).unwrap();
        for _ in 0..150 {
            call = execute_wrapping(&call);
        }
        assert!(parse_wrapped(call).is_err());
    }

    #[test]
    fn test_parse_real_multisig_propose_transfer() {
        // propose wrapping Balances::transfer_allow_death(dest, 42_000_000_000), expiry 5000
        match parse_call_hex("13019999999999999999999999999999999999999999999999999999999999999999a4020000777777777777777777777777777777777777777777777777777777777777777707002465c70988130000") {
            QuantusTx::MultisigPropose { multisig, expiry, inner } => {
                assert_eq!(multisig, SS58_MULTISIG);
                assert_eq!(expiry, 5000);
                assert_transfer(&inner, SS58_DEST, 42_000_000_000u128, false, None);
            }
            other => panic!("expected MultisigPropose, got {:?}", other),
        }
    }

    fn propose_wrapping(inner: &[u8]) -> Vec<u8> {
        let mut call = vec![0x13, 0x01];
        call.extend_from_slice(&[0x99; 32]);
        call.extend(Compact(inner.len() as u32).encode());
        call.extend_from_slice(inner);
        call.extend_from_slice(&5000u32.to_le_bytes());
        call
    }

    #[test]
    fn test_multisig_nesting_depth_limit() {
        let transfer = hex::decode(TRANSFER_CALL_1).unwrap();

        // propose(propose(transfer)) — inner calls at depth 1 and 2 — is accepted.
        let mut payload = propose_wrapping(&propose_wrapping(&transfer));
        payload.extend(ext_suffix(&[0x00], 0, 0, &PLANCK_GENESIS));
        assert!(parse_payload(&payload).is_ok());

        // One more level of nesting exceeds MAX_CALL_DEPTH and is rejected.
        let mut payload = propose_wrapping(&propose_wrapping(&propose_wrapping(&transfer)));
        payload.extend(ext_suffix(&[0x00], 0, 0, &PLANCK_GENESIS));
        let err = parse_payload(&payload).unwrap_err();
        assert!(err.contains("depth limit"), "{}", err);
    }

    #[test]
    fn test_deep_nesting_bomb_rejected_quickly() {
        // The audit's C-1 payload shape: hundreds of nested propose levels. Must fail on one
        // of the counters — depth, payload size, or call size — not by exhausting the stack.
        let mut call = hex::decode(TRANSFER_CALL_1).unwrap();
        for _ in 0..300 {
            call = propose_wrapping(&call);
        }
        call.extend(ext_suffix(&[0x00], 0, 0, &PLANCK_GENESIS));
        let err = parse_payload(&call).unwrap_err();
        assert!(
            err.contains("depth limit") || err.contains("too large") || err.contains("review limit"),
            "{}",
            err
        );
    }

    #[test]
    fn test_reject_trailing_bytes_inside_inner_call() {
        let mut inner = hex::decode(TRANSFER_CALL_1).unwrap();
        inner.push(0xff);
        let mut payload = propose_wrapping(&inner);
        payload.extend(ext_suffix(&[0x00], 0, 0, &PLANCK_GENESIS));
        let err = parse_payload(&payload).unwrap_err();
        assert!(err.contains("trailing bytes after call"), "{}", err);
    }
}
