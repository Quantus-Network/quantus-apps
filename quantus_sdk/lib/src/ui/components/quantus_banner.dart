import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Sage settles, sand warns, ember fails, glacier waits.
enum BannerTone {
  sage('\u2713'),
  sand('!'),
  ember('!'),
  glacier('!');

  const BannerTone(this.glyph);

  /// Shown in the icon ring when the caller supplies no [QuantusBanner.leading].
  final String glyph;
}

enum _BannerLayout { message, titled, stacked }

/// Shared v3 status banner; [QuantusBanner.stacked] is the centered funds-safe
/// variant and [QuantusBanner.titled] puts the glyph inline with a heading.
class QuantusBanner extends StatelessWidget {
  final BannerTone tone;
  final String message;

  /// Defaults to [BannerTone.glyph]; a tone-blind default put '!' on success.
  final Widget? leading;
  final String? label;
  final String? amount;
  final _BannerLayout _layout;

  const QuantusBanner({super.key, required this.tone, required this.message, this.leading})
    : label = null,
      amount = null,
      _layout = _BannerLayout.message;

  /// Leading glyph inline with [label], message below in muted caption.
  const QuantusBanner.titled({
    super.key,
    required this.tone,
    required String this.label,
    required Widget this.leading,
    required this.message,
  }) : amount = null,
       _layout = _BannerLayout.titled;

  /// Centered label + amount + muted caption. No icon.
  const QuantusBanner.stacked({
    super.key,
    required this.tone,
    required String this.label,
    required String this.amount,
    required this.message,
  }) : leading = null,
       _layout = _BannerLayout.stacked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final foreground = _toneColor(colors, tone);

    return _BannerChrome(
      foreground: foreground,
      child: switch (_layout) {
        _BannerLayout.stacked => _StackedBody(foreground: foreground, label: label!, amount: amount!, message: message),
        _BannerLayout.titled => _TitledBody(foreground: foreground, title: label!, message: message, leading: leading!),
        _BannerLayout.message => _MessageBody(
          foreground: foreground,
          message: message,
          leading: leading ?? Text(tone.glyph),
        ),
      },
    );
  }
}

class _BannerChrome extends StatelessWidget {
  final Color foreground;
  final Widget child;

  const _BannerChrome({required this.foreground, required this.child});

  @override
  Widget build(BuildContext context) {
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
  final Widget leading;

  const _MessageBody({required this.foreground, required this.message, required this.leading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BannerIcon(foreground: foreground, child: leading),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message, style: context.themeTextV3.caption.copyWith(color: foreground, height: 1.5)),
        ),
      ],
    );
  }
}

class _TitledBody extends StatelessWidget {
  final Color foreground;
  final String title;
  final String message;
  final Widget leading;

  const _TitledBody({required this.foreground, required this.title, required this.message, required this.leading});

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            leading,
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: text.body.copyWith(color: foreground)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(message, style: text.caption.copyWith(color: context.colorsV3.textMuted)),
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
      child: DefaultTextStyle(
        style: context.themeTextV3.body.copyWith(color: foreground, height: 1),
        child: child,
      ),
    );
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
