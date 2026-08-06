import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Renders a UR payload as a QR code. A multi-part UR is animated by cycling
/// through its fragments with a [Timer] (no post-frame callbacks). Reacts to
/// [fps], [paused] and [parts] changes so the animation can be tuned live.
class AnimatedUrQr extends StatefulWidget {
  final List<String> parts;
  final int fps;
  final bool paused;
  final double size;

  const AnimatedUrQr({super.key, required this.parts, required this.fps, this.paused = false, this.size = 280});

  @override
  State<AnimatedUrQr> createState() => _AnimatedUrQrState();
}

class _AnimatedUrQrState extends State<AnimatedUrQr> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(AnimatedUrQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parts.length != oldWidget.parts.length) _index = 0;
    if (widget.fps != oldWidget.fps ||
        widget.paused != oldWidget.paused ||
        widget.parts.length != oldWidget.parts.length) {
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
      child: QrImageView(
        data: widget.parts[_index],
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        version: QrVersions.auto,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
      ),
    );
  }
}
