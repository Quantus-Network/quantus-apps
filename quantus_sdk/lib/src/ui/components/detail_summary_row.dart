import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Density for [DetailSummaryRow] until design picks one layout.
enum DetailSummaryLayout {
  /// Sheet/list: label left, value right.
  compact,

  /// Signing review: label above value, wrap, no ellipsis.
  stacked,
}

/// Label/value row used in review screens, detail sheets, and signing.
class DetailSummaryRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final int labelFlex;
  final int valueFlex;
  final EdgeInsetsGeometry padding;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final DetailSummaryLayout layout;

  /// Monospace value, for addresses, hashes and byte blobs. [stacked] only.
  final bool monospace;

  final Color? valueColor;

  /// Caveat shown under the value. [stacked] only.
  final String? note;

  const DetailSummaryRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.labelFlex = 2,
    this.valueFlex = 3,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.labelStyle,
    this.valueStyle,
    this.layout = DetailSummaryLayout.compact,
    this.monospace = false,
    this.valueColor,
    this.note,
  }) : assert(value != null || valueWidget != null);

  factory DetailSummaryRow.review({
    Key? key,
    required String label,
    String? value,
    Widget? valueWidget,
    int valueFlex = 3,
    TextStyle? valueStyle,
  }) {
    return DetailSummaryRow(
      key: key,
      label: label,
      value: value,
      valueWidget: valueWidget,
      valueFlex: valueFlex,
      valueStyle: valueStyle,
      padding: EdgeInsets.zero,
    );
  }

  /// Label-above-value row. Values wrap rather than ellipsize so a signer can
  /// read a full address or hash.
  const DetailSummaryRow.stacked({
    super.key,
    required this.label,
    required String this.value,
    this.monospace = false,
    this.valueColor,
    this.note,
  }) : valueWidget = null,
       labelFlex = 2,
       valueFlex = 3,
       labelStyle = null,
       valueStyle = null,
       layout = DetailSummaryLayout.stacked,
       padding = const EdgeInsets.symmetric(vertical: 10);

  @override
  Widget build(BuildContext context) {
    return layout == DetailSummaryLayout.stacked ? _stacked(context) : _compact(context);
  }

  Widget _compact(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;
    final effectiveLabelStyle = labelStyle ?? _labelStyle(text, colors);
    final effectiveValueStyle = valueStyle ?? text.body.copyWith(color: colors.textContent);

    return Container(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(label, style: effectiveLabelStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: valueFlex,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  valueWidget ?? Text(value!, style: effectiveValueStyle, textAlign: TextAlign.right, softWrap: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stacked(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: _labelStyle(text, colors)),
          const SizedBox(height: 6),
          Text(
            value!,
            style: (monospace ? text.dataAddressLarge : text.body).copyWith(color: valueColor ?? colors.textContent),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: text.caption.copyWith(color: colors.textMuted)),
          ],
        ],
      ),
    );
  }

  TextStyle _labelStyle(AppTextThemeV3 text, AppColorsV3 colors) {
    return text.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: colors.textMuted);
  }
}
