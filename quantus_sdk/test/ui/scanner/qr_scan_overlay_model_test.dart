import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/signing/ur_scan_collector.dart';
import 'package:quantus_sdk/src/ui/components/scanner/qr_detection.dart';
import 'package:quantus_sdk/src/ui/components/scanner/qr_scan_overlay_model.dart';

final _header = RegExp(r'^ur:t/(\d+)-(\d+)/');

({int index, int total})? _sequenceFor(String part) {
  final match = _header.firstMatch(part);
  return match == null ? null : (index: int.parse(match[1]!), total: int.parse(match[2]!));
}

UrScanCollector _collector({int maxParts = 256}) => UrScanCollector(
  acceptsPart: (part) => part.startsWith('ur:'),
  isComplete: (parts) =>
      parts.isNotEmpty &&
      parts.map(_sequenceFor).whereType<Object>().length == _sequenceFor(parts.first)!.total &&
      parts.toSet().length == _sequenceFor(parts.first)!.total,
  sequenceFor: _sequenceFor,
  maxParts: maxParts,
);

QrDetection _frame(int index, int total, {Offset at = const Offset(500, 300)}) => QrDetection(
  raw: 'ur:t/$index-$total/x',
  corners: [at, at + const Offset(80, 0), at + const Offset(80, 80), at + const Offset(0, 80)],
  imageSize: const Size(1280, 720),
);

QrScanOverlayModel _model({QrPartCollector? collector}) =>
    QrScanOverlayModel(collector: collector ?? _collector())..setPreviewSize(const Size(640, 360));

void main() {
  test('a detection places the code and the first accepted frame starts collecting', () {
    final model = _model();
    var notifications = 0;
    model.addListener(() => notifications++);

    expect(model.onDetection(_frame(1, 3)), UrScanOutcome.added);
    expect(model.phase, QrScanPhase.collecting);
    expect(model.quad, isNotNull);
    expect(model.quad!.first, const Offset(250, 150));
    expect(model.partCount, 1);
    expect(model.expected, 3);
    expect(model.lastAddedIndex, 1);
    expect(model.missingIndexes, {2, 3});
    expect(model.progress, closeTo(1 / 3, 1e-9));
    expect(model.detectedTick, 1);
    expect(model.pulseTick, 1);
    expect(notifications, 1);
    model.dispose();
  });

  test('a duplicate frame keeps the phase and moves the code smoothly', () {
    final model = _model();
    model.onDetection(_frame(1, 3));
    expect(model.onDetection(_frame(1, 3, at: const Offset(540, 300))), UrScanOutcome.duplicate);
    expect(model.phase, QrScanPhase.collecting);
    expect(model.quad!.first.dx, closeTo(260, 1e-9));
    expect(model.pulseTick, 1);
    model.dispose();
  });

  test('losing the code fades to idle but keeps the collected frames', () {
    fakeAsync((async) {
      final model = _model();
      model.onDetection(_frame(1, 3));
      async.elapse(const Duration(milliseconds: 400));
      expect(model.phase, QrScanPhase.lost);
      expect(model.quad, isNotNull);
      async.elapse(const Duration(milliseconds: 250));
      expect(model.phase, QrScanPhase.idle);
      expect(model.quad, isNull);
      expect(model.partCount, 1);

      model.onDetection(_frame(2, 3));
      expect(model.phase, QrScanPhase.collecting);
      expect(model.detectedTick, 2);
      expect(model.seen, {1, 2});
      model.dispose();
    });
  });

  test('completion fires once and later detections are ignored', () {
    fakeAsync((async) {
      final model = _model();
      model.onDetection(_frame(1, 2));
      expect(model.onDetection(_frame(2, 2)), UrScanOutcome.complete);
      expect(model.phase, QrScanPhase.complete);
      expect(model.completeTick, 1);
      expect(model.onDetection(_frame(2, 2)), UrScanOutcome.ignored);
      async.elapse(const Duration(seconds: 5));
      expect(model.phase, QrScanPhase.complete);
      model.dispose();
    });
  });

  test('a stall is flagged after three seconds without a new frame', () {
    fakeAsync((async) {
      final model = _model();
      model.onDetection(_frame(1, 3));
      async.elapse(const Duration(seconds: 2));
      model.onDetection(_frame(1, 3));
      async.elapse(const Duration(milliseconds: 1500));
      expect(model.stalled, isTrue);
      model.onDetection(_frame(2, 3));
      expect(model.stalled, isFalse);
      model.dispose();
    });
  });

  test('overflow and a failed completion reset through a short error phase', () {
    fakeAsync((async) {
      final model = _model(collector: _collector(maxParts: 1));
      model.onDetection(_frame(1, 9));
      expect(model.onDetection(_frame(2, 9)), UrScanOutcome.overflow);
      expect(model.phase, QrScanPhase.error);
      expect(model.partCount, 0);
      async.elapse(const Duration(milliseconds: 1200));
      expect(model.phase, QrScanPhase.idle);
      expect(model.quad, isNull);

      model.onDetection(_frame(1, 1));
      expect(model.phase, QrScanPhase.complete);
      model.reportFailure();
      expect(model.phase, QrScanPhase.error);
      expect(model.partCount, 0);
      async.elapse(const Duration(milliseconds: 1200));
      expect(model.phase, QrScanPhase.idle);
      expect(model.onDetection(_frame(1, 1)), UrScanOutcome.complete);
      model.dispose();
    });
  });

  test('a mirrored preview flips the placement', () {
    final model = _model()..mirrored = true;
    model.onDetection(_frame(1, 3));
    expect(model.quad!.map((p) => p.dx).reduce((a, b) => a < b ? a : b), closeTo(640 - 290, 1e-9));
    model.dispose();
  });
}
