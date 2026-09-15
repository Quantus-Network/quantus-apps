import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Status-grammar tones for [QuantusBadge].
///
/// Glacier waits, sage settles, ember fails, sand warns. Lilac is checkphrase
/// only. Flare is reserved for action emphasis.
enum BadgeTone { neutral, sage, sand, ember, glacier, lilac, flare }

/// Stroke-only status badge: mono uppercase, tracked, tone on stroke and text.
///
/// Presentational only. Callers pass an already-resolved [label].
class QuantusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  /// Leading status dot in the tone colour.
  final bool dot;

  const QuantusBadge({super.key, required this.label, this.tone = BadgeTone.neutral, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context.colorsV3, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: context.radiusV3.xsBorder,
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
          ],
          Text(label.toUpperCase(), style: _labelStyle(context, color), maxLines: 1, softWrap: false),
        ],
      ),
    );
  }

  /// Figma Badge type: Geist Mono Medium 10, tracking 0.8, from Label / Monogram.
  TextStyle _labelStyle(BuildContext context, Color color) {
    return context.themeTextV3.labelMonogram.copyWith(fontSize: 10, letterSpacing: 0.8, color: color);
  }
}

Color _toneColor(AppColorsV3 colors, BadgeTone tone) {
  return switch (tone) {
    BadgeTone.neutral => colors.textMuted,
    BadgeTone.sage => colors.semanticSage,
    BadgeTone.sand => colors.semanticSand,
    BadgeTone.ember => colors.semanticEmber,
    BadgeTone.glacier => colors.semanticGlacier,
    BadgeTone.lilac => colors.semanticLilac,
    BadgeTone.flare => colors.accentFlare,
  };
}
