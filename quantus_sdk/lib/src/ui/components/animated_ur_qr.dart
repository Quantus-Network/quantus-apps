import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Renders a UR payload as a QR code. A multi-part UR is animated by cycling
/// through its fragments with a [Timer]. A single-part UR renders statically.
class AnimatedUrQr extends StatefulWidget {
  final List<String> parts;
  final Duration interval;
  final double size;

  const AnimatedUrQr({
    super.key,
    required this.parts,
    this.interval = const Duration(milliseconds: 200),
    this.size = 280,
  });

  @override
  State<AnimatedUrQr> createState() => _AnimatedUrQrState();
}

class _AnimatedUrQrState extends State<AnimatedUrQr> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.parts.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) {
        setState(() => _index = (_index + 1) % widget.parts.length);
      });
    }
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
