import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A camera [preview] with the scanning overlay: the picture stays dark until
/// a code is found, which is then lit and followed while [collector] gathers
/// its frames. The host owns the camera; it feeds [detections] and is told
/// through [onComplete] when the payload is in. A failing [onComplete] is
/// reported through [onError] and the scan starts over.
class QrScanView extends StatefulWidget {
  final QrPartCollector collector;
  final Stream<QrDetection> detections;
  final Widget preview;
  final Future<void> Function(List<String> parts) onComplete;
  final FutureOr<void> Function(Object error)? onError;
  final QrScanStrings strings;
  final bool mirrored;
  final bool showFrameMap;

  const QrScanView({
    super.key,
    required this.collector,
    required this.detections,
    required this.preview,
    required this.onComplete,
    required this.strings,
    this.onError,
    this.mirrored = false,
    this.showFrameMap = true,
  });

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> with TickerProviderStateMixin {
  late final QrScanOverlayModel _model = QrScanOverlayModel(collector: widget.collector, mirrored: widget.mirrored);
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  StreamSubscription<QrDetection>? _subscription;
  int _detectedTick = 0;
  int _pulseTick = 0;
  int _completeTick = 0;

  @override
  void initState() {
    super.initState();
    _model.addListener(_animate);
    _subscription = widget.detections.listen(_onDetection);
  }

  @override
  void didUpdateWidget(QrScanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _model.mirrored = widget.mirrored;
    if (oldWidget.detections != widget.detections) {
      _subscription?.cancel();
      _subscription = widget.detections.listen(_onDetection);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _model.removeListener(_animate);
    _model.dispose();
    _reveal.dispose();
    _pulse.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _animate() {
    if (_model.detectedTick != _detectedTick) {
      _detectedTick = _model.detectedTick;
      _reveal.forward(from: 0);
    }
    if (_model.pulseTick != _pulseTick) {
      _pulseTick = _model.pulseTick;
      _pulse.forward(from: 0);
    }
    if (_model.completeTick != _completeTick) {
      _completeTick = _model.completeTick;
      _flash.forward(from: 0);
    }
  }

  void _onDetection(QrDetection detection) {
    if (_model.onDetection(detection) == UrScanOutcome.complete) unawaited(_complete());
  }

  Future<void> _complete() async {
    try {
      await widget.onComplete(_model.collector.parts);
    } catch (error) {
      await widget.onError?.call(error);
      if (mounted) _model.reportFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _model.setPreviewSize(constraints.biggest);
        return ClipRRect(
          borderRadius: context.radiusV3.mdBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.preview,
              IgnorePointer(
                child: CustomPaint(
                  painter: QrScanOverlayPainter(
                    model: _model,
                    colors: context.colorsV3,
                    reveal: _reveal,
                    pulse: _pulse,
                    completeFlash: _flash,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: QrScanHud(
                  model: _model,
                  strings: widget.strings,
                  flash: _pulse,
                  showFrameMap: widget.showFrameMap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
