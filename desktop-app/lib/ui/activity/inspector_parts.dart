import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

// What the pages of the panel at the window's right are made of, whatever
// they show: a transaction, a proposal, the swap.

/// A small label in capitals, as Send's receipt heads its blocks.
TextStyle inspectorCapsStyle(BuildContext context, {Color? color}) => context.themeTextV3.dataAddress.copyWith(
  height: 1,
  letterSpacing: 2.4,
  color: color ?? context.colorsV3.textMuted2,
);

/// The amount a page leads with, or a dash for none.
Widget inspectorHeadline(BuildContext context, String text) => Text(
  text,
  style: context.themeTextV3.titleHero.copyWith(
    fontSize: 26,
    height: 1.05,
    letterSpacing: -0.65,
    color: context.colorsV3.textWhite,
  ),
);

/// A line of the status: its mark, its word in capitals, and what follows.
Widget inspectorStatusLine(
  BuildContext context, {
  Widget? mark,
  required String label,
  required Color color,
  String? after,
}) {
  final caps = inspectorCapsStyle(context, color: color);
  return SizedBox(
    height: 14,
    child: Row(
      children: [
        if (mark != null) ...[mark, const SizedBox(width: 8)],
        CapsText(label, style: caps),
        if (after != null) ...[
          const SizedBox(width: 12),
          Text(
            after,
            style: context.themeTextV3.body.copyWith(
              color: context.colorsV3.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    ),
  );
}

/// A row's label, quiet.
Widget inspectorLabel(BuildContext context, String text) =>
    Text(text, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted));
