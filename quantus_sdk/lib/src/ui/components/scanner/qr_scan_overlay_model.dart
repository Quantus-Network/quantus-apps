import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/src/signing/ur_scan_collector.dart';
import 'package:quantus_sdk/src/ui/components/scanner/qr_detection.dart';
import 'package:quantus_sdk/src/ui/components/scanner/qr_scan_geometry.dart';

enum QrScanPhase { idle, detected, collecting, lost, complete, error }

/// What the scanner overlay shows: the phase, the smoothed position of the QR
/// in the preview, and the collector's progress. Frames collected so far
/// survive the code leaving the camera's view.
class QrScanOverlayModel extends ChangeNotifier {
  final QrPartCollector collector;
  final Duration lostAfter;
  final Duration idleAfterLost;
  final Duration stallAfter;
  final Duration errorFor;

  QrScanPhase _phase = QrScanPhase.idle;
  List<Offset>? _quad;
  Size _previewSize = Size.zero;
  bool mirrored;
  Set<int> _seenBefore = const {};
  int? _lastAddedIndex;
  bool _stalled = false;
  int _detectedTick = 0;
  int _pulseTick = 0;
  int _completeTick = 0;
  Timer? _lostTimer;
  Timer? _idleTimer;
  Timer? _stallTimer;
  Timer? _errorTimer;

  QrScanOverlayModel({
    required this.collector,
    this.mirrored = false,
    this.lostAfter = const Duration(milliseconds: 400),
    this.idleAfterLost = const Duration(milliseconds: 250),
    this.stallAfter = const Duration(seconds: 3),
    this.errorFor = const Duration(milliseconds: 1200),
  });

  QrScanPhase get phase => _phase;
  List<Offset>? get quad => _quad;
  Size get previewSize => _previewSize;
  int get partCount => collector.parts.length;
  Set<int> get seen => collector.seen;
  int? get expected => collector.expected;
  int? get lastAddedIndex => _lastAddedIndex;
  bool get stalled => _stalled;

  /// Bumped on each idle-to-detected transition, accepted frame, and completion;
  /// the view starts its animations off these.
  int get detectedTick => _detectedTick;
  int get pulseTick => _pulseTick;
  int get completeTick => _completeTick;

  double? get progress {
    final total = expected;
    return total == null || total == 0 ? null : (seen.length / total).clamp(0.0, 1.0);
  }

  Set<int> get missingIndexes {
    final total = expected;
    if (total == null) return const {};
    return {for (var i = 1; i <= total; i++) i}..removeAll(seen);
  }

  void setPreviewSize(Size size) {
    if (size == _previewSize) return;
    _previewSize = size;
  }

  /// The outcome the collector reported, so the host can stop its camera on
  /// [UrScanOutcome.complete].
  UrScanOutcome onDetection(QrDetection detection) {
    if (_phase == QrScanPhase.complete || _phase == QrScanPhase.error) return UrScanOutcome.ignored;
    _place(detection);
    if (_phase == QrScanPhase.idle || _phase == QrScanPhase.lost) {
      _idleTimer?.cancel();
      _phase = partCount > 0 ? QrScanPhase.collecting : QrScanPhase.detected;
      _detectedTick++;
    }
    _armLostWatchdog();

    final outcome = collector.accept(detection.raw);
    switch (outcome) {
      case UrScanOutcome.added:
      case UrScanOutcome.restarted:
        _phase = QrScanPhase.collecting;
        final added = collector.seen.difference(_seenBefore);
        _lastAddedIndex = added.isEmpty ? null : added.first;
        _seenBefore = collector.seen;
        _pulseTick++;
        _stalled = false;
        _armStallTimer();
      case UrScanOutcome.complete:
        _phase = QrScanPhase.complete;
        _completeTick++;
        _cancelTimers();
      case UrScanOutcome.overflow:
        _enterError();
      case UrScanOutcome.ignored:
      case UrScanOutcome.duplicate:
        break;
    }
    notifyListeners();
    return outcome;
  }

  void _place(QrDetection detection) {
    final mapped = normalizeQuad(
      mapCornersToPreview(detection.corners, detection.imageSize, _previewSize, mirrored: mirrored),
    );
    if (mapped.isEmpty) return;
    final current = _quad;
    if (current == null) {
      _quad = mapped;
      return;
    }
    var moved = false;
    for (var i = 0; i < 4; i++) {
      if ((mapped[i] - current[i]).distance >= 1.5) moved = true;
    }
    if (!moved) return;
    _quad = [for (var i = 0; i < 4; i++) Offset.lerp(current[i], mapped[i], 0.5)!];
  }

  void _armLostWatchdog() {
    _lostTimer?.cancel();
    _lostTimer = Timer(lostAfter, () {
      if (_phase != QrScanPhase.detected && _phase != QrScanPhase.collecting) return;
      _phase = QrScanPhase.lost;
      notifyListeners();
      _idleTimer = Timer(idleAfterLost, () {
        if (_phase != QrScanPhase.lost) return;
        _phase = QrScanPhase.idle;
        _quad = null;
        notifyListeners();
      });
    });
  }

  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(stallAfter, () {
      if (_phase == QrScanPhase.complete) return;
      _stalled = true;
      notifyListeners();
    });
  }

  void _enterError() {
    _cancelTimers();
    collector.reset();
    _seenBefore = const {};
    _lastAddedIndex = null;
    _stalled = false;
    _phase = QrScanPhase.error;
    _errorTimer = Timer(errorFor, () {
      _phase = QrScanPhase.idle;
      _quad = null;
      notifyListeners();
    });
  }

  /// Decoding or submitting the completed payload failed: start over.
  void reportFailure() {
    _enterError();
    notifyListeners();
  }

  void reset() {
    _cancelTimers();
    collector.reset();
    _seenBefore = const {};
    _lastAddedIndex = null;
    _stalled = false;
    _phase = QrScanPhase.idle;
    _quad = null;
    notifyListeners();
  }

  void _cancelTimers() {
    _lostTimer?.cancel();
    _idleTimer?.cancel();
    _stallTimer?.cancel();
    _errorTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
