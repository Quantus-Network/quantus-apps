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
  const FigureRow({super.key, required this.label, required this.value, this.isStrong = false});

  final String label;
  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    return SummaryRow(
      label: Text(
        label,
        style: context.themeTextV3.body.copyWith(
          color: isStrong ? context.colorsV3.textContent : context.colorsV3.textMuted,
        ),
      ),
      value: FigureText(value, isStrong: isStrong),
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
