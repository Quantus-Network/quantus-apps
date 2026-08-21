import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Renders a UR payload as a QR code. A multi-part UR is animated by cycling
/// through its fragments with a [Timer] (no post-frame callbacks). Reacts to
/// [fps], [paused] and [parts] changes so the animation can be tuned live.
///
/// Every frame's QR is encoded once up front: encoding a dense QR takes long
/// enough that doing it inside build caps the real frame rate well below the
/// requested one. Painting a precomputed module matrix keeps ticks cheap.
class AnimatedUrQr extends StatefulWidget {
  final List<String> parts;
  final int fps;
  final bool paused;
  final double size;

  const AnimatedUrQr({super.key, required this.parts, this.fps = 15, this.paused = false, this.size = 280})
    : assert(fps > 0, 'AnimatedUrQr fps must be positive');

  @override
  State<AnimatedUrQr> createState() => _AnimatedUrQrState();
}

class _AnimatedUrQrState extends State<AnimatedUrQr> {
  Timer? _timer;
  int _index = 0;
  late List<QrPainter> _painters;

  @override
  void initState() {
    super.initState();
    _painters = _buildPainters();
    _restartTimer();
  }

  List<QrPainter> _buildPainters() {
    assert(widget.parts.isNotEmpty, 'AnimatedUrQr requires at least one UR part');
    return widget.parts
        .map(
          (part) => QrPainter.withQr(
            qr: QrCode.fromData(data: part, errorCorrectLevel: QrErrorCorrectLevel.L),
            gapless: true,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
          ),
        )
        .toList();
  }

  @override
  void didUpdateWidget(AnimatedUrQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    final partsChanged = !identical(widget.parts, oldWidget.parts);
    if (partsChanged) {
      _painters = _buildPainters();
      _index = 0;
    }
    if (partsChanged || widget.fps != oldWidget.fps || widget.paused != oldWidget.paused) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.paused || widget.parts.length <= 1) return;
    _timer = Timer.periodic(Duration(milliseconds: (1000 / widget.fps).round()), (_) {
      setState(() => _index = (_index + 1) % widget.parts.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: CustomPaint(painter: _painters[_index]),
    );
  }
}
