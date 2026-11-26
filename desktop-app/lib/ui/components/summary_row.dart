import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A label and what stands for it, at the two ends of a line.
class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key, required this.label, required this.value});

  final Widget label;
  final Widget value;

  static const padding = EdgeInsets.symmetric(vertical: 9);

  /// How tall a row is, whether it holds a line of text or an account's
  /// badge, so the rows step down evenly. One that needs more grows.
  static const double height = 34;

  /// The least space between the label and what stands for it.
  static const double gap = 16;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: height),
      child: Row(
        children: [
          label,
          const SizedBox(width: gap),
          Expanded(
            child: Align(alignment: AlignmentDirectional.centerEnd, child: value),
          ),
        ],
      ),
    );
  }
}

/// A label and its figure at the two ends of a line.
class FigureRow extends StatelessWidget {
  const FigureRow({
    super.key,
    required this.label,
    required String this.value,
    this.isStrong = false,
    this.updating = false,
  });

  /// The line of a figure not known yet, turning where it will stand.
  const FigureRow.loading({super.key, required this.label, this.isStrong = false}) : value = null, updating = false;

  final String label;
  final String? value;
  final bool isStrong;

  /// The figure is the one before, standing while the new one is worked
  /// out: it turns beside it.
  final bool updating;

  @override
  Widget build(BuildContext context) {
    return SummaryRow(
      label: Text(
        label,
        style: context.themeTextV3.body.copyWith(
          color: isStrong ? context.colorsV3.textContent : context.colorsV3.textMuted,
        ),
      ),
      value: switch (value) {
        final value? when updating => UpdatingFigure(value, isStrong: isStrong),
        final value? => FigureText(value, isStrong: isStrong),
        null => const FigureLoader(),
      },
    );
  }
}

/// Where a figure not known yet will stand, as Send's fee says it is on its
/// way.
class FigureLoader extends StatelessWidget {
  const FigureLoader({super.key});

  @override
  Widget build(BuildContext context) => const Loader(size: 12);
}

/// A figure that stands while the new one is worked out, turning beside it.
class UpdatingFigure extends StatelessWidget {
  const UpdatingFigure(this.value, {super.key, this.isStrong = false});

  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FigureLoader(),
        const SizedBox(width: 8),
        Flexible(child: FigureText(value, isStrong: isStrong)),
      ],
    );
  }
}

/// A figure, or other short text, at the end of its line.
class FigureText extends StatelessWidget {
  const FigureText(this.value, {super.key, this.isStrong = false});

  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;

    return Text(
      value,
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
      style: (isStrong ? text.bodyEmphasis : text.body).copyWith(
        color: context.colorsV3.textContent,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
