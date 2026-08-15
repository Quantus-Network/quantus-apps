import 'package:quantus_sdk/src/rust/api/ur.dart';

/// Sequence header of a multi-part UR frame (`ur:type/seqNum-seqLen/...`),
/// digit-bounded so attacker headers can't overflow int parsing.
final RegExp _urSequencePattern = RegExp(r'/(\d{1,6})-(\d{1,6})/');

/// Extracts the (index, total) sequence header of a UR frame, or null for
/// single-part payloads, which carry no sequence header.
({int index, int total})? urSequenceFor(String part) {
  final match = _urSequencePattern.firstMatch(part);
  if (match == null) return null;
  return (index: int.parse(match.group(1)!), total: int.parse(match.group(2)!));
}

/// Whether a scanned QR string is acceptable as a UR frame: ur: prefix,
/// bounded length, and a declared fragment count within [maxUrParts].
/// The caps live in the Rust UR API (rust/src/api/ur.rs) and are read through
/// the generated getters, so inbound and decode-time limits cannot drift apart.
bool isAcceptableUrPart(String part) {
  if (part.length > maxUrPartChars()) return false;
  if (!part.toLowerCase().startsWith('ur:')) return false;
  final total = urSequenceFor(part)?.total;
  return total == null || (total >= 1 && total <= maxUrParts());
}

/// Encodes [data] as UR parts that each fit in a single QR code.
///
/// [maxFragmentLength] bounds the payload bytes per frame, but the QR limit is
/// on the encoded string: bytewords doubles every byte and the UR header adds
/// more, so an in-range byte setting can still yield an oversized frame. The
/// encoded parts are measured and the fragment size lowered until every frame
/// fits [maxUrPartChars] — the version-40 byte-mode capacity at error
/// correction L.
List<String> encodeUrForQr({required List<int> data, required int maxFragmentLength}) {
  final frameChars = maxUrPartChars();
  var fragmentLength = maxFragmentLength;
  while (true) {
    final parts = encodeUr(data: data, maxFragmentLength: fragmentLength);
    var longest = 0;
    for (final part in parts) {
      if (part.length > longest) longest = part.length;
    }
    if (longest <= frameChars) return parts;
    final actualFragment = (data.length / parts.length).ceil();
    final next = actualFragment - ((longest - frameChars) / 2).ceil();
    if (next < 1) throw StateError('UR frame of $longest chars cannot fit a QR code');
    fragmentLength = next < fragmentLength ? next : fragmentLength - 1;
  }
}
