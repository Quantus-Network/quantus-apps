import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quantus_sdk/src/extensions/color_extensions.dart';
import 'package:quantus_sdk/src/ui/components/scanner/qr_scan_geometry.dart';
import 'package:quantus_sdk/src/ui/components/scanner/qr_scan_overlay_model.dart';
import 'package:quantus_sdk/src/ui/themes/app_colors.dart';

/// Darkens the preview except for the detected code and a softer window
/// around the device showing it.
class QrScanOverlayPainter extends CustomPainter {
  final QrScanOverlayModel model;
  final AppColorsV3 colors;
  final Animation<double> reveal;
  final Animation<double> pulse;
  final Animation<double> completeFlash;

  QrScanOverlayPainter({
    required this.model,
    required this.colors,
    required this.reveal,
    required this.pulse,
    required this.completeFlash,
  }) : super(repaint: Listenable.merge([model, reveal, pulse, completeFlash]));

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final quad = model.quad;
    final phase = model.phase;
    if (quad == null || phase == QrScanPhase.idle) {
      canvas.drawRect(full, Paint()..color = colors.bgVoid.useOpacity(0.85));
      final side = math.min(size.width, size.height) * 0.6;
      canvas.drawRect(
        Rect.fromCenter(center: full.center, width: side, height: side),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.textContent.useOpacity(0.15),
      );
      return;
    }

    final revealValue = Curves.easeOutCubic.transform(reveal.value);
    final qrPath = quadPath(scaleQuad(quad, 0.6 + 0.4 * revealValue));
    final devicePath = deviceHighlightRect(quad, size).toPath();
    final complete = phase == QrScanPhase.complete;

    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(full), devicePath),
      Paint()..color = colors.bgVoid.useOpacity(complete ? 0.92 : 0.85),
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference, devicePath, qrPath),
      Paint()..color = colors.bgVoid.useOpacity(0.45),
    );
    canvas.drawPath(
      devicePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.textContent.useOpacity(0.25),
    );

    final stroke = switch (phase) {
      QrScanPhase.error => colors.semanticEmber,
      QrScanPhase.complete => colors.semanticSage,
      _ => colors.accentFlare,
    };
    final glow = (phase == QrScanPhase.lost ? 0.3 : 0.55) * revealValue;
    canvas.drawPath(
      qrPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = stroke.useOpacity(glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final pulseAlpha = 1 - 0.4 * math.sin(math.pi * pulse.value);
    canvas.drawPath(
      qrPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = stroke.useOpacity(pulseAlpha * revealValue),
    );
    if (complete) {
      canvas.drawPath(qrPath, Paint()..color = colors.accentFlare.useOpacity(0.35 * (1 - completeFlash.value)));
    }
  }

  @override
  bool shouldRepaint(QrScanOverlayPainter oldDelegate) => oldDelegate.model != model || oldDelegate.colors != colors;
}
