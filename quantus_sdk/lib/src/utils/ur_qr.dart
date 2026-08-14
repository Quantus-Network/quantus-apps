import 'package:quantus_sdk/src/rust/api/ur.dart';

/// Character capacity of a version-40 QR code in byte mode at error
/// correction L — the hard ceiling for a single UR frame string.
const int maxUrQrFrameChars = 2953;

/// Encodes [data] as UR parts that each fit in a single QR code.
///
/// [maxFragmentLength] bounds the payload bytes per frame, but the QR limit is
/// on the encoded string: bytewords doubles every byte and the UR header adds
/// more, so an in-range byte setting can still yield an oversized frame. The
/// encoded parts are measured and the fragment size lowered until every frame
/// fits [maxUrQrFrameChars].
List<String> encodeUrForQr({required List<int> data, required int maxFragmentLength}) {
  var fragmentLength = maxFragmentLength;
  while (true) {
    final parts = encodeUr(data: data, maxFragmentLength: fragmentLength);
    var longest = 0;
    for (final part in parts) {
      if (part.length > longest) longest = part.length;
    }
    if (longest <= maxUrQrFrameChars) return parts;
    final actualFragment = (data.length / parts.length).ceil();
    final next = actualFragment - ((longest - maxUrQrFrameChars) / 2).ceil();
    if (next < 1) throw StateError('UR frame of $longest chars cannot fit a QR code');
    fragmentLength = next < fragmentLength ? next : fragmentLength - 1;
  }
}
