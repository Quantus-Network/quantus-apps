/// UR API for parsing QR codes in the ur:.. standard
///
use quantus_ur::{decode_bytes, encode_bytes, encode_bytes_with_options, is_complete};

/// Inbound caps, the single source of truth for UR scan limits — Dart reads
/// them through the generated getters below (see ur_qr.dart). Scanned UR
/// frames are attacker-controlled: without a bound, a hostile sequence could
/// grow the accumulated parts (and any allocation the decoder keys off them)
/// without limit. The largest legitimate payload (a 7,219-byte ML-DSA
/// signature at the minimum 50-byte fragment setting) needs ~145 frames, so
/// these caps never fire on honest input.
const MAX_UR_PARTS: usize = 256;
const MAX_UR_PART_CHARS: usize = 2953;

#[flutter_rust_bridge::frb(sync)]
pub fn max_ur_parts() -> u32 {
    MAX_UR_PARTS as u32
}

#[flutter_rust_bridge::frb(sync)]
pub fn max_ur_part_chars() -> u32 {
    MAX_UR_PART_CHARS as u32
}

fn within_limits(ur_parts: &[String]) -> bool {
    ur_parts.len() <= MAX_UR_PARTS as usize
        && ur_parts.iter().all(|p| p.len() <= MAX_UR_PART_CHARS as usize)
}

// Note decode_ur takes the list of QR Codes in any order and assembles them correctly.
// It also deals with the weird elements that are created in the UR standard when we exceed the number
// of segments.
// For example if you have 3 segments, and the scanner scans all 3 but doesn't succeed, subsequent parts
// are sent with strange numbers like /412-3/ which are encoded with pieces of the previous segments so that
// the algorithm recovers faster than just repeating the segments over and over. This is described in the UR
// standard. FYI.
#[flutter_rust_bridge::frb(sync)]
pub fn decode_ur(ur_parts: Vec<String>) -> Result<Vec<u8>, String> {
    if !within_limits(&ur_parts) {
        return Err("UR input exceeds scan limits".to_string());
    }
    decode_bytes(&ur_parts).map_err(|e| e.to_string())
}

// max_fragment_length is the payload bytes per QR frame; None uses the
// quantus_ur default (200).
#[flutter_rust_bridge::frb(sync)]
pub fn encode_ur(data: Vec<u8>, max_fragment_length: Option<u32>) -> Result<Vec<String>, String> {
    match max_fragment_length {
        Some(len) => encode_bytes_with_options(&data, len as usize),
        None => encode_bytes(&data),
    }
    .map_err(|e| e.to_string())
}

#[flutter_rust_bridge::frb(sync)]
pub fn is_complete_ur(ur_parts: Vec<String>) -> bool {
    if !within_limits(&ur_parts) {
        return false;
    }
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

        assert!(
            is_complete_ur(encoded_parts),
            "Single part should be complete"
        );
    }

    #[test]
    fn test_is_complete_multi_part_complete() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000".repeat(10);
        let payload_bytes = hex::decode(&hex_payload).expect("Hex decode failed");
        let encoded_parts = encode_ur(payload_bytes, None).expect("Encoding failed");

        assert!(
            is_complete_ur(encoded_parts),
            "All parts should be complete"
        );
    }

    #[test]
    fn test_is_complete_multi_part_incomplete() {
        let hex_payload = "0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000".repeat(10);
        let payload_bytes = hex::decode(&hex_payload).expect("Hex decode failed");
        let encoded_parts = encode_ur(payload_bytes, None).expect("Encoding failed");

        assert!(encoded_parts.len() > 1, "Should have multiple parts");

        let incomplete_parts = vec![encoded_parts[0].clone()];
        assert!(
            !is_complete_ur(incomplete_parts),
            "Incomplete parts should return false"
        );
    }

    #[test]
    fn test_fragment_length_controls_part_count() {
        let payload_bytes = vec![0xABu8; 3000];

        let small = encode_ur(payload_bytes.clone(), Some(300)).expect("Encoding failed");
        let large = encode_ur(payload_bytes.clone(), Some(1500)).expect("Encoding failed");
        assert!(
            small.len() > large.len(),
            "Smaller fragments should produce more parts"
        );

        assert_eq!(decode_ur(small).expect("Decoding failed"), payload_bytes);
        assert_eq!(decode_ur(large).expect("Decoding failed"), payload_bytes);
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
        assert_eq!(
            decoded_bytes, payload_bytes,
            "Decoding should work regardless of part order"
        );

        assert!(
            is_complete_ur(scrambled_parts),
            "Scrambled parts should still be complete"
        );
    }

    #[test]
    fn test_decode_rejects_too_many_parts() {
        let parts = vec!["ur:bytes/1-1/aaaa".to_string(); MAX_UR_PARTS + 1];
        assert!(decode_ur(parts).is_err());
    }

    #[test]
    fn test_decode_rejects_overlong_part() {
        let parts = vec!["a".repeat(MAX_UR_PART_CHARS + 1)];
        assert!(decode_ur(parts).is_err());
    }

    #[test]
    fn test_is_complete_rejects_over_limit_input() {
        let parts = vec!["ur:bytes/1-1/aaaa".to_string(); MAX_UR_PARTS + 1];
        assert!(!is_complete_ur(parts));
    }

    #[test]
    fn test_limits_getters() {
        assert_eq!(max_ur_parts() as usize, MAX_UR_PARTS);
        assert_eq!(max_ur_part_chars() as usize, MAX_UR_PART_CHARS);
    }
}
