/// UR API for parsing QR codes in the ur:.. standard
///
use quantus_ur::{decode, encode};
use hex;

#[flutter_rust_bridge::frb(sync)]
pub fn decode_ur(ur_parts: Vec<String>) -> Result<Vec<u8>, String> {
    let decoded_hex = decode(&ur_parts).map_err(|e| e.to_string())?;
    let decoded_bytes = hex::decode(decoded_hex).map_err(|e| format!("Failed to decode hex: {}", e))?;
    Ok(decoded_bytes)
}

#[flutter_rust_bridge::frb(sync)]
pub fn encode_ur(data: Vec<u8>) -> Result<Vec<String>, String> {
    let hex_data = hex::encode(data);
    encode(&hex_data).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_single_part_roundtrip() {
        // Small payload that fits in 200 bytes
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000";
        
        let encoded_parts = encode(hex_payload).expect("Encoding failed");
        assert_eq!(encoded_parts.len(), 1, "Should be single part");
        
        let decoded_hex = decode(&encoded_parts).expect("Decoding failed");
        assert_eq!(decoded_hex.to_lowercase(), hex_payload.to_lowercase());
    }
}
