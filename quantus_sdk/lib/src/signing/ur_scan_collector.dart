import 'package:quantus_sdk/src/rust/api/ur.dart';
import 'package:quantus_sdk/src/utils/ur_qr.dart';

enum UrScanOutcome { ignored, duplicate, added, restarted, overflow, complete }

/// Accumulates the frames of an animated QR payload until they decode. On
/// [UrScanOutcome.complete] the caller reads [parts].
abstract class QrPartCollector {
  List<String> get parts;
  Set<int> get seen;
  int? get expected;
  bool get done;
  UrScanOutcome accept(String part);
  void reset();
}

/// Collects multi-part UR frames. Frames from a different animation (another
/// declared total) restart the set, and a set that has every index but still
/// fails to decode is retried on its newest suffixes, so a stale frame left
/// over from an earlier animation cannot block completion.
class UrScanCollector implements QrPartCollector {
  final bool Function(String part) _acceptsPart;
  final bool Function(List<String> parts) _isComplete;
  final ({int index, int total})? Function(String part) _sequenceFor;
  final int _maxParts;

  final List<String> _parts = [];
  final Set<String> _partSet = {};
  final Set<int> _seen = {};
  int? _expected;
  bool _done = false;

  UrScanCollector({
    bool Function(String part)? acceptsPart,
    bool Function(List<String> parts)? isComplete,
    ({int index, int total})? Function(String part)? sequenceFor,
    int? maxParts,
  }) : _acceptsPart = acceptsPart ?? isAcceptableUrPart,
       _isComplete = isComplete ?? ((parts) => isCompleteUr(urParts: parts)),
       _sequenceFor = sequenceFor ?? urSequenceFor,
       _maxParts = maxParts ?? maxUrScanParts;

  @override
  List<String> get parts => List.unmodifiable(_parts);

  @override
  Set<int> get seen => Set.unmodifiable(_seen);

  @override
  int? get expected => _expected;

  Set<int> get missingIndexes {
    final total = _expected;
    if (total == null) return const {};
    return {for (var i = 1; i <= total; i++) i}..removeAll(_seen);
  }

  @override
  bool get done => _done;

  @override
  UrScanOutcome accept(String part) {
    if (_done || !_acceptsPart(part)) return UrScanOutcome.ignored;
    final sequence = _sequenceFor(part);
    var restarted = false;
    if (sequence != null && _expected != null && sequence.total != _expected) {
      reset();
      restarted = true;
    }
    if (_parts.length >= _maxParts) {
      reset();
      return UrScanOutcome.overflow;
    }
    if (!_partSet.add(part)) return UrScanOutcome.duplicate;
    _parts.add(part);
    if (sequence != null) {
      _seen.add(sequence.index);
      _expected = sequence.total;
    }
    if (!_settleComplete()) return restarted ? UrScanOutcome.restarted : UrScanOutcome.added;
    _done = true;
    return UrScanOutcome.complete;
  }

  bool _settleComplete() {
    if (_isComplete(_parts)) return true;
    final total = _expected;
    if (total == null || _seen.length < total) return false;
    for (var start = 1; start <= _parts.length - total; start++) {
      if (_isComplete(_parts.sublist(start))) {
        _parts.removeRange(0, start);
        _partSet
          ..clear()
          ..addAll(_parts);
        return true;
      }
    }
    return false;
  }

  @override
  void reset() {
    _parts.clear();
    _partSet.clear();
    _seen.clear();
    _expected = null;
    _done = false;
  }
}

/// Completes on the first frame [validator] accepts (a single static QR).
class SingleQrCollector implements QrPartCollector {
  final bool Function(String value) validator;
  String? _value;
  bool _done = false;

  SingleQrCollector({required this.validator});

  @override
  List<String> get parts => _value == null ? const [] : [_value!];

  @override
  Set<int> get seen => _value == null ? const {} : const {1};

  @override
  int? get expected => 1;

  @override
  bool get done => _done;

  @override
  UrScanOutcome accept(String part) {
    if (_done) return UrScanOutcome.ignored;
    if (!validator(part)) return UrScanOutcome.ignored;
    _value = part;
    _done = true;
    return UrScanOutcome.complete;
  }

  @override
  void reset() {
    _value = null;
    _done = false;
  }
}
