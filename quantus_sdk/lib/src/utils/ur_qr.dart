import 'package:quantus_sdk/src/rust/api/ur.dart';

/// Scan limits, defined once in the Rust UR API (rust/src/api/ur.rs) and read
/// through the generated getters so inbound and decode-time bounds cannot drift
/// apart. Cached because the scanners consult them on every camera frame.
final int maxUrScanParts = maxUrParts();
final int maxUrScanPartChars = maxUrPartChars();

/// Sequence header of a multi-part UR frame (`ur:type/seqNum-seqLen/...`),
/// anchored so only a real header matches and a hostile one is rejected rather
/// than mistaken for a header-less single-part frame.
final RegExp _urSequencePattern = RegExp(r'^ur:[^/]+/(\d+)-(\d+)/', caseSensitive: false);

/// Extracts the (index, total) sequence header of a UR frame, or null for
/// single-part payloads, which carry no sequence header. Counts beyond the int
/// range also yield null; [isAcceptableUrPart] drops those frames.
({int index, int total})? urSequenceFor(String part) {
  final match = _urSequencePattern.firstMatch(part);
  return match == null ? null : _sequenceFromMatch(match);
}

({int index, int total})? _sequenceFromMatch(RegExpMatch match) {
  final index = int.tryParse(match.group(1)!);
  final total = int.tryParse(match.group(2)!);
  if (index == null || total == null) return null;
  return (index: index, total: total);
}

/// Whether a scanned QR string is acceptable as a UR frame: ur: prefix, bounded
/// length, and — when it carries a sequence header — a fragment count within
/// [maxUrScanParts] and an index inside that count, matching what the decoder
/// accepts.
bool isAcceptableUrPart(String part) {
  if (!part.toLowerCase().startsWith('ur:')) return false;
  if (part.length > maxUrScanPartChars) return false;
  final match = _urSequencePattern.firstMatch(part);
  if (match == null) return true;
  final sequence = _sequenceFromMatch(match);
  if (sequence == null) return false;
  return sequence.index >= 1 && sequence.index <= sequence.total && sequence.total <= maxUrScanParts;
}

/// Encodes [data] as UR parts that each fit in a single QR code.
///
/// [maxFragmentLength] bounds the payload bytes per frame, but the QR limit is
/// on the encoded string: bytewords doubles every byte and the UR header adds
/// more, so an in-range byte setting can still yield an oversized frame. The
/// encoded parts are measured and the fragment size lowered until every frame
/// fits [maxUrScanPartChars] — the version-40 byte-mode capacity at error
/// correction L.
List<String> encodeUrForQr({required List<int> data, required int maxFragmentLength}) {
  var fragmentLength = maxFragmentLength;
  while (true) {
    final parts = encodeUr(data: data, maxFragmentLength: fragmentLength);
    // Fail here rather than emitting frames every scanner would refuse.
    if (parts.length > maxUrScanParts) {
      throw StateError('UR payload needs ${parts.length} frames, above the $maxUrScanParts scan limit');
    }
    var longest = 0;
    for (final part in parts) {
      if (part.length > longest) longest = part.length;
    }
    if (longest <= maxUrScanPartChars) return parts;
    final actualFragment = (data.length / parts.length).ceil();
    final next = actualFragment - ((longest - maxUrScanPartChars) / 2).ceil();
    if (next < 1) throw StateError('UR frame of $longest chars cannot fit a QR code');
    fragmentLength = next < fragmentLength ? next : fragmentLength - 1;
  }
}
