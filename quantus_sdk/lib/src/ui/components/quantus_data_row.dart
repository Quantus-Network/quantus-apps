import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Declared data row: mono label left, mono value right, hairline border.
///
/// Figma Row / Spec. Presentational only. Callers pass already-resolved [label] and [value] strings.
/// Tappable rows pass [onTap] and an affordance [trailing] glyph.
class QuantusDataRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const QuantusDataRow({super.key, required this.label, required this.value, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    final row = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline, width: 1),
      ),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: _labelStyle(text, colors), maxLines: 1, softWrap: false),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: text.dataAddress.copyWith(color: colors.textContent),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    if (onTap == null) return row;

    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }

  /// Figma Row / Spec label: Geist Mono Medium 10, tracking 1, from Label / Monogram.
  TextStyle _labelStyle(AppTextThemeV3 text, AppColorsV3 colors) {
    return text.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: colors.textMuted);
  }
}
