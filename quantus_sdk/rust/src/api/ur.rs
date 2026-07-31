/// UR API for parsing QR codes in the ur:.. standard
///
use quantus_ur::{decode_bytes, encode_bytes, encode_bytes_with_options, is_complete};

// Note decode_ur takes the list of QR Codes in any order and assembles them correctly.
// Only the simple parts 1..=N are emitted and accepted; mixed fountain parts
// (sequence > sequence_count) are rejected by quantus_ur.
#[flutter_rust_bridge::frb(sync)]
pub fn decode_ur(ur_parts: Vec<String>) -> Result<Vec<u8>, String> {
    decode_bytes(&ur_parts).map_err(|e| e.to_string())
}

#[flutter_rust_bridge::frb(sync)]
pub fn encode_ur(data: Vec<u8>, max_fragment_length: Option<u32>) -> Result<Vec<String>, String> {
    match max_fragment_length {
        Some(len) => encode_bytes_with_options(&data, len as usize).map_err(|e| e.to_string()),
        None => encode_bytes(&data).map_err(|e| e.to_string()),
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn is_complete_ur(ur_parts: Vec<String>) -> bool {
    is_complete(&ur_parts)
}
#[cfg(test)]
mod tests {
    use super::*;
    use hex;

    #[test]
    fn test_single_part_roundtrip() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000";
        let payload_bytes = hex::decode(hex_payload).expect("Hex decode failed");
        
        let encoded_parts = encode_ur(payload_bytes.clone(), None).expect("Encoding failed");
        assert_eq!(encoded_parts.len(), 1, "Should be single part");
        
        let decoded_bytes = decode_ur(encoded_parts).expect("Decoding failed");
        assert_eq!(decoded_bytes, payload_bytes);
    }

    #[test]
    fn test_multi_part_roundtrip() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000".repeat(10);
        let payload_bytes = hex::decode(&hex_payload).expect("Hex decode failed");
        
        let encoded_parts = encode_ur(payload_bytes.clone(), None).expect("Encoding failed");
        assert!(encoded_parts.len() > 1, "Should be multiple parts");
        
        let decoded_bytes = decode_ur(encoded_parts).expect("Decoding failed");
        assert_eq!(decoded_bytes, payload_bytes);
    }

    #[test]
    fn test_is_complete_single_part() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000";
        let payload_bytes = hex::decode(hex_payload).expect("Hex decode failed");
        let encoded_parts = encode_ur(payload_bytes, None).expect("Encoding failed");
        
        assert!(is_complete_ur(encoded_parts), "Single part should be complete");
    }

    #[test]
    fn test_is_complete_multi_part_complete() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000".repeat(10);
        let payload_bytes = hex::decode(&hex_payload).expect("Hex decode failed");
        let encoded_parts = encode_ur(payload_bytes, None).expect("Encoding failed");
        
        assert!(is_complete_ur(encoded_parts), "All parts should be complete");
    }

    #[test]
    fn test_is_complete_multi_part_incomplete() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000".repeat(10);
        let payload_bytes = hex::decode(&hex_payload).expect("Hex decode failed");
        let encoded_parts = encode_ur(payload_bytes, None).expect("Encoding failed");
        
        assert!(encoded_parts.len() > 1, "Should have multiple parts");
        
        let incomplete_parts = vec![encoded_parts[0].clone()];
        assert!(!is_complete_ur(incomplete_parts), "Incomplete parts should return false");
    }

    #[test]
    fn test_large_fragment_roundtrip() {
        let payload_bytes: Vec<u8> = (0..7219u32).map(|i| (i % 251) as u8).collect();
        let encoded_parts =
            encode_ur(payload_bytes.clone(), Some(1500)).expect("Encoding failed");
        assert_eq!(encoded_parts.len(), 5, "7219 bytes at 1500 per fragment");
        let decoded_bytes = decode_ur(encoded_parts).expect("Decoding failed");
        assert_eq!(decoded_bytes, payload_bytes);
    }

    #[test]
    fn test_multi_part_out_of_order() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000".repeat(10);
        let payload_bytes = hex::decode(&hex_payload).expect("Hex decode failed");
        let encoded_parts = encode_ur(payload_bytes.clone(), None).expect("Encoding failed");
        
        assert!(encoded_parts.len() > 1, "Should be multiple parts");
        
        let mut scrambled_parts = encoded_parts.clone();
        scrambled_parts.reverse();
        let mid = scrambled_parts.len() / 2;
        scrambled_parts.swap(0, mid);
        
        let decoded_bytes = decode_ur(scrambled_parts.clone()).expect("Decoding failed");
        assert_eq!(decoded_bytes, payload_bytes, "Decoding should work regardless of part order");
        
        assert!(is_complete_ur(scrambled_parts), "Scrambled parts should still be complete");
    }

}
