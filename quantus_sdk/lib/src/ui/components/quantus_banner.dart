import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Status grammar for [QuantusBanner].
///
/// Sage settles, sand warns, ember fails, glacier waits.
enum BannerTone { sage, sand, ember, glacier }

/// Shared v3 status banner: tone gradient fill, 10% stroke, 40px icon circle.
///
/// Presentational only. Callers pass an already-resolved [message].
class QuantusBanner extends StatelessWidget {
  final BannerTone tone;
  final String message;
  final Widget? leading;

  const QuantusBanner({super.key, required this.tone, required this.message, this.leading});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final foreground = _toneColor(colors, tone);
    // Dark stop is tone mixed toward void so we do not add colors absent from the Figma table.
    final fillEnd = Color.lerp(foreground, colors.bgVoid, 0.75)!;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [foreground.useOpacity(0.25), fillEnd.useOpacity(0.25)],
        ),
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: foreground.useOpacity(0.10), width: 1),
      ),
      child: Row(
        children: [
          _BannerIcon(
            foreground: foreground,
            child: leading ?? _DefaultBannerGlyph(foreground: foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: context.themeTextV3.caption.copyWith(color: foreground, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _BannerIcon extends StatelessWidget {
  final Color foreground;
  final Widget child;

  const _BannerIcon({required this.foreground, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: foreground.useOpacity(0.25), width: 1),
      ),
      child: child,
    );
  }
}

class _DefaultBannerGlyph extends StatelessWidget {
  final Color foreground;

  const _DefaultBannerGlyph({required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Text('!', style: context.themeTextV3.body.copyWith(color: foreground, height: 1));
  }
}

Color _toneColor(AppColorsV3 colors, BannerTone tone) {
  return switch (tone) {
    BannerTone.sage => colors.semanticSage,
    BannerTone.sand => colors.semanticSand,
    BannerTone.ember => colors.semanticEmber,
    BannerTone.glacier => colors.semanticGlacier,
  };
}
