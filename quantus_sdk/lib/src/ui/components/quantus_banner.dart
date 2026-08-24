import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Status grammar for [QuantusBanner].
///
/// Sage settles, sand warns, ember fails, glacier waits.
enum BannerTone { sage, sand, ember, glacier }

/// Shared v3 status banner: tone gradient fill, 10% stroke.
///
/// Default is icon + wrapping caption (Figma Banner). [QuantusBanner.stacked]
/// is the centered funds-safe anchor: label, amount, muted caption.
///
/// Presentational only. Callers pass already-resolved copy.
class QuantusBanner extends StatelessWidget {
  final BannerTone tone;
  final String message;
  final Widget? leading;
  final String? label;
  final String? amount;
  final bool _stacked;

  const QuantusBanner({super.key, required this.tone, required this.message, this.leading})
    : label = null,
      amount = null,
      _stacked = false;

  /// Centered label + amount + muted caption. No icon.
  const QuantusBanner.stacked({
    super.key,
    required this.tone,
    required String this.label,
    required String this.amount,
    required this.message,
  }) : leading = null,
       _stacked = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final foreground = _toneColor(colors, tone);

    return _BannerChrome(
      foreground: foreground,
      child: _stacked
          ? _StackedBody(foreground: foreground, label: label!, amount: amount!, message: message)
          : _MessageBody(foreground: foreground, message: message, leading: leading),
    );
  }
}

class _BannerChrome extends StatelessWidget {
  final Color foreground;
  final Widget child;

  const _BannerChrome({required this.foreground, required this.child});

  @override
  Widget build(BuildContext context) {
    // Dark stop is tone mixed toward void so we do not add colors absent from the Figma table.
    final fillEnd = Color.lerp(foreground, context.colorsV3.bgVoid, 0.75)!;

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
      child: child,
    );
  }
}

class _MessageBody extends StatelessWidget {
  final Color foreground;
  final String message;
  final Widget? leading;

  const _MessageBody({required this.foreground, required this.message, this.leading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BannerIcon(
          foreground: foreground,
          child: leading ?? _DefaultBannerGlyph(foreground: foreground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message, style: context.themeTextV3.caption.copyWith(color: foreground)),
        ),
      ],
    );
  }
}

class _StackedBody extends StatelessWidget {
  final Color foreground;
  final String label;
  final String amount;
  final String message;

  const _StackedBody({required this.foreground, required this.label, required this.amount, required this.message});

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), textAlign: TextAlign.center, style: _labelStyle(context)),
        const SizedBox(height: 6),
        Text(
          amount,
          textAlign: TextAlign.center,
          style: text.amountHero.copyWith(color: foreground),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.caption.copyWith(color: context.colorsV3.textMuted),
        ),
      ],
    );
  }

  /// Figma Funds Safe Anchor kicker: Geist Mono Medium 10, tracking 1, from Label / Monogram.
  TextStyle _labelStyle(BuildContext context) {
    return context.themeTextV3.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: foreground);
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
    return Text('!', style: context.themeTextV3.body.copyWith(color: foreground));
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
