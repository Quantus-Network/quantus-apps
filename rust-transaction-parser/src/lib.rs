use parity_scale_codec::{Decode, Compact};
use std::fmt;

#[derive(Debug, PartialEq)]
pub struct TransactionInfo {
    pub to_address: String,
    pub amount: u128,
    pub is_reversible: bool,
    pub reversible_timeframe: Option<u64>,
}

impl fmt::Display for TransactionInfo {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let amount_str = format!("{:.4}", self.amount as f64 / 10_f64.powi(10));
        write!(f, "Transaction Details:\n  To Address: {}\n  Amount: {} QUS\n  Reversible: {}",
               self.to_address, amount_str, self.is_reversible)?;

        if self.is_reversible && self.reversible_timeframe.is_some() {
            write!(f, "\n  Reversible Timeframe: {} milliseconds ", self.reversible_timeframe.unwrap())?;
        }

        Ok(())
    }
}

pub struct QuantusPayloadParser;

impl QuantusPayloadParser {
    pub fn bytes_to_ss58(bytes: &[u8]) -> String {
        const SS58_PREFIX: u16 = 189; // Quantus SS58 prefix
        
        if bytes.len() != 32 {
            panic!("AccountId32 must be 32 bytes");
        }
        
        let mut account_id_bytes = [0u8; 32];
        account_id_bytes.copy_from_slice(bytes);
        
        ss58::encode(&account_id_bytes, ss58::Ss58AddressFormat::Custom(SS58_PREFIX))
    }

    pub fn parse_payload(payload: &[u8]) -> Result<TransactionInfo, String> {
        let mut input = &payload[..];

        // Read pallet index (first byte)
        let pallet_index: u8 = Decode::decode(&mut input).map_err(|e| e.to_string())?;

        // Read the call data (remaining bytes)
        let call_data = input;

        match pallet_index {
            2 => Self::parse_balances_call(call_data), // Balances pallet
            13 => Self::parse_reversible_transfers_call(call_data), // ReversibleTransfers pallet
            _ => Err("Unknown pallet".to_string()), // Unknown pallet
        }
    }

    fn parse_balances_call(call_data: &[u8]) -> Result<TransactionInfo, String> {
        let mut input = call_data;

        // Read call index
        let call_index: u8 = Decode::decode(&mut input).map_err(|e| e.to_string())?;

        match call_index {
            0 | 3 => { // transfer_allow_death or transfer_keep_alive
                let dest = Self::parse_multi_address(&mut input)?;
                let amount: Compact<u128> = Decode::decode(&mut input).map_err(|e| e.to_string())?;
                Ok(TransactionInfo {
                    to_address: dest,
                    amount: amount.0,
                    is_reversible: false,
                    reversible_timeframe: None,
                })
            }
            _ => Err(format!("Balances: Unsupported call index {}", call_index)),
        }
    }

    fn parse_reversible_transfers_call(call_data: &[u8]) -> Result<TransactionInfo, String> {
        let mut input = call_data;

        // Read call index
        let call_index: u8 = Decode::decode(&mut input).map_err(|e| e.to_string())?;

        match call_index {
            3 => { // schedule_transfer
                let dest = Self::parse_multi_address(&mut input)?;
                let amount: u128 = Decode::decode(&mut input).map_err(|e| e.to_string())?;
                Ok(TransactionInfo {
                    to_address: dest,
                    amount,
                    is_reversible: true,
                    reversible_timeframe: None, // Uses configured delay
                })
            }
            4 => { // schedule_transfer_with_delay
                let dest = Self::parse_multi_address(&mut input)?;
                let amount: u128 = Decode::decode(&mut input).map_err(|e| e.to_string())?;
                let delay = Self::parse_block_number_or_timestamp(&mut input)?;
                Ok(TransactionInfo {
                    to_address: dest,
                    amount,
                    is_reversible: true,
                    reversible_timeframe: Some(delay),
                })
            }
            _ => Err(format!("ReversibleTransfers: Unsupported call index {}", call_index)),
        }
    }

    fn parse_multi_address(input: &mut &[u8]) -> Result<String, String> {
        let address_type: u8 = Decode::decode(input).map_err(|e| e.to_string())?;

        match address_type {
            0 => { // Id(AccountId)
                let account_id: [u8; 32] = Decode::decode(input).map_err(|e| e.to_string())?;
                Ok(Self::bytes_to_ss58(&account_id))
            }
            1 => Err("Index(Compact<u32>) MultiAddress type 1 is not supported".to_string()),
            2 => Err("Raw(Vec<u8>) MultiAddress type 2 is not supported".to_string()),
            3 => Err("Address32([u8; 32]) MultiAddress type 3 is not supported".to_string()),
            4 => Err("Address20([u8; 20]) MultiAddress type 4 is not supported".to_string()),
            _ => Err(format!("Unknown multi address type: {}", address_type)),
        }
    }

    fn parse_block_number_or_timestamp(input: &mut &[u8]) -> Result<u64, String> {
        let variant: u8 = Decode::decode(input).map_err(|e| e.to_string())?;

        match variant {
            0 => Err("Block numbers are not supported for delayed transactions".to_string()),
            1 => { // Timestamp(u64)
                let timestamp: u64 = Decode::decode(input).map_err(|e| e.to_string())?;
                Ok(timestamp)
            }
            _ => Err(format!("Unknown time variant: {}", variant)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use hex;

    #[test]
    fn test_parse_real_world_balance_transfer() {
        let hex_payload = "020000ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb40700282e8cd185012800007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e3d3e081c6e3599f8ae31d404d9f087f50c25b4e08c35712e23470a60da5799ca00";
        let payload = hex::decode(hex_payload).unwrap();
        let expected_address = "qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86";
        let expected_amount = 900000000000u128;

        let result = QuantusPayloadParser::parse_payload(&payload);

        assert!(result.is_ok());
        let tx = result.unwrap();
        assert_eq!(tx.amount, expected_amount);
        assert_eq!(tx.is_reversible, false);
        assert_eq!(tx.reversible_timeframe, None);
        assert_eq!(tx.to_address, expected_address);
    }

    #[test]
    fn test_parse_real_world_reversible_transfer() {
        let hex_payload = "0d04007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0040b0464f010000000000000000000001e093040000000000d5010c00007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118efeebb9b31159a679a1e49ccc34d363b5d4a00b836ad4f85cbba8c6274ac2566800";
        let payload = hex::decode(hex_payload).unwrap();
        let expected_address = "qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG";
        let expected_amount = 1440000000000u128;
        let expected_delay = 300000u64; // 5 minutes in milliseconds

        let result = QuantusPayloadParser::parse_payload(&payload);

        assert!(result.is_ok());
        let tx = result.unwrap();
        assert_eq!(tx.amount, expected_amount);
        assert_eq!(tx.is_reversible, true);
        assert_eq!(tx.reversible_timeframe, Some(expected_delay));
        assert_eq!(tx.to_address, expected_address);
    }
}