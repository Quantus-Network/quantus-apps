import 'dart:typed_data';

import 'package:quantus_sdk/src/rust/api/ur.dart';
import 'package:quantus_sdk/src/utils/ur_qr.dart';

/// What became of one code read by [UrScanAccumulator.add].
sealed class UrScanResult {
  const UrScanResult();
}

/// Not a frame to keep: not an acceptable UR frame, one already scanned, or
/// one read after the payload was complete.
final class UrScanIgnored extends UrScanResult {
  const UrScanIgnored();
}

/// A new frame was kept: [scanned] of the [total] the sequence declares, which
/// is null until a frame carrying a sequence header has been read.
final class UrScanProgress extends UrScanResult {
  final int scanned;
  final int? total;

  const UrScanProgress({required this.scanned, required this.total});
}

/// The frames make up the whole payload.
final class UrScanComplete extends UrScanResult {
  final Uint8List payload;

  const UrScanComplete(this.payload);
}

/// The frame limit was reached without the payload completing, so it never
/// can: the frames were dropped and the scan starts over.
final class UrScanOverflow extends UrScanResult {
  const UrScanOverflow();
}

/// The complete frames did not decode; they were dropped and the scan starts
/// over.
final class UrScanFailed extends UrScanResult {
  final Object error;

  const UrScanFailed(this.error);
}

/// Collects the frames of an animated UR QR code, read one by one in any
/// order, until they make up the whole payload.
///
/// The checks default to the Rust UR API; they can be replaced where it is
/// not loaded.
class UrScanAccumulator {
  UrScanAccumulator({
    bool Function(String part)? isAcceptable,
    bool Function(List<String> parts)? isComplete,
    Uint8List Function(List<String> parts)? decode,
    int? maxParts,
  }) : _isAcceptable = isAcceptable ?? isAcceptableUrPart,
       _isComplete = isComplete ?? ((parts) => isCompleteUr(urParts: parts)),
       _decode = decode ?? ((parts) => decodeUr(urParts: parts)),
       _maxParts = maxParts ?? maxUrScanParts;

  final bool Function(String part) _isAcceptable;
  final bool Function(List<String> parts) _isComplete;
  final Uint8List Function(List<String> parts) _decode;

  /// Bounds the frames kept: a hostile animation could otherwise keep
  /// showing new frames and grow memory without limit.
  final int _maxParts;

  final Set<String> _parts = {};
  final Set<int> _sequenceIndexes = {};
  int? _total;
  bool _isDone = false;

  /// How many of the sequence's frames have been read.
  int get scanned => _sequenceIndexes.length;

  /// How many frames the sequence declares, once one has been read.
  int? get total => _total;

  /// Takes one code read by the camera.
  UrScanResult add(String code) {
    if (_isDone || !_isAcceptable(code) || _parts.contains(code)) return const UrScanIgnored();
    if (_parts.length >= _maxParts) {
      reset();
      return const UrScanOverflow();
    }
    _parts.add(code);
    final sequence = urSequenceFor(code);
    if (sequence != null) {
      _sequenceIndexes.add(sequence.index);
      _total = sequence.total;
    }

    final parts = _parts.toList(growable: false);
    if (!_isComplete(parts)) return UrScanProgress(scanned: scanned, total: _total);
    try {
      final payload = _decode(parts);
      _isDone = true;
      return UrScanComplete(payload);
    } catch (error) {
      reset();
      return UrScanFailed(error);
    }
  }

  /// Drops every frame read, to scan from the start.
  void reset() {
    _parts.clear();
    _sequenceIndexes.clear();
    _total = null;
    _isDone = false;
  }
}
