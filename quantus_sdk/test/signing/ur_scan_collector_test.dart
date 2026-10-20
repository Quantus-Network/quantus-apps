import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/signing/ur_scan_collector.dart';

final _header = RegExp(r'^ur:t/(\d+)-(\d+)/');

({int index, int total})? _sequenceFor(String part) {
  final match = _header.firstMatch(part);
  return match == null ? null : (index: int.parse(match[1]!), total: int.parse(match[2]!));
}

String _frame(int index, int total, [String stream = 'a']) => 'ur:t/$index-$total/$stream';

String _stream(String part) => part.split('/').last;

/// Models the real decoder: it locks onto the first frame's message, so a set
/// mixing two animations never completes.
bool _isComplete(List<String> parts) {
  if (parts.isEmpty) return false;
  final stream = _stream(parts.first);
  final total = _sequenceFor(parts.first)!.total;
  final indexes = <int>{};
  for (final part in parts) {
    if (_stream(part) != stream) return false;
    indexes.add(_sequenceFor(part)!.index);
  }
  return indexes.length == total;
}

UrScanCollector _collector({int maxParts = 256}) => UrScanCollector(
  acceptsPart: (part) => part.startsWith('ur:'),
  isComplete: _isComplete,
  sequenceFor: _sequenceFor,
  maxParts: maxParts,
);

void main() {
  test('ignores non-UR frames and dedupes repeats', () {
    final collector = _collector();

    expect(collector.accept('https://quantus.com'), UrScanOutcome.ignored);
    expect(collector.accept(_frame(1, 3)), UrScanOutcome.added);
    expect(collector.accept(_frame(1, 3)), UrScanOutcome.duplicate);
    expect(collector.parts, [_frame(1, 3)]);
    expect(collector.seen, {1});
    expect(collector.expected, 3);
    expect(collector.missingIndexes, {2, 3});
  });

  test('completes once with every frame and ignores frames afterwards', () {
    final collector = _collector();

    collector.accept(_frame(2, 3));
    collector.accept(_frame(1, 3));
    expect(collector.accept(_frame(3, 3)), UrScanOutcome.complete);
    expect(collector.done, isTrue);
    expect(collector.accept(_frame(3, 3)), UrScanOutcome.ignored);
    expect(collector.parts, [_frame(2, 3), _frame(1, 3), _frame(3, 3)]);
  });

  test('a frame with another declared total starts a new set', () {
    final collector = _collector();

    collector.accept(_frame(1, 3));
    collector.accept(_frame(2, 3));
    expect(collector.accept(_frame(1, 5, 'b')), UrScanOutcome.restarted);
    expect(collector.parts, [_frame(1, 5, 'b')]);
    expect(collector.seen, {1});
    expect(collector.expected, 5);
  });

  test('recovers from stale frames of an earlier animation with the same total', () {
    final collector = _collector();

    collector.accept(_frame(1, 3, 'old'));
    collector.accept(_frame(2, 3, 'old'));
    collector.accept(_frame(1, 3, 'new'));
    collector.accept(_frame(2, 3, 'new'));
    expect(collector.accept(_frame(3, 3, 'new')), UrScanOutcome.complete);
    expect(collector.parts, [_frame(1, 3, 'new'), _frame(2, 3, 'new'), _frame(3, 3, 'new')]);
  });

  test('overflow resets the set and reports it', () {
    final collector = _collector(maxParts: 2);

    collector.accept(_frame(1, 9));
    collector.accept(_frame(2, 9));
    expect(collector.accept(_frame(3, 9)), UrScanOutcome.overflow);
    expect(collector.parts, isEmpty);
    expect(collector.expected, isNull);
  });

  test('reset after a failed completion accepts frames again', () {
    final collector = _collector();

    collector.accept(_frame(1, 1));
    expect(collector.done, isTrue);
    collector.reset();
    expect(collector.done, isFalse);
    expect(collector.accept(_frame(1, 1)), UrScanOutcome.complete);
  });

  test('single-part frames complete without a header', () {
    final collector = UrScanCollector(
      acceptsPart: (part) => part.startsWith('ur:'),
      isComplete: (parts) => parts.length == 1,
      sequenceFor: (_) => null,
      maxParts: 4,
    );

    expect(collector.accept('ur:t/single'), UrScanOutcome.complete);
    expect(collector.expected, isNull);
    expect(collector.parts, ['ur:t/single']);
  });

  test('SingleQrCollector completes on the first valid value only', () {
    final collector = SingleQrCollector(validator: (value) => value.startsWith('qz'));

    expect(collector.accept('nope'), UrScanOutcome.ignored);
    expect(collector.accept('qzabc'), UrScanOutcome.complete);
    expect(collector.accept('qzdef'), UrScanOutcome.ignored);
    expect(collector.parts, ['qzabc']);
    expect(collector.seen, {1});
    expect(collector.expected, 1);
  });
}
