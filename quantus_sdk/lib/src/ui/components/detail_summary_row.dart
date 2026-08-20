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

  /// Monospace value, for addresses, hashes and byte blobs.
  final bool monospace;

  final Color? valueColor;

  /// Caveat shown under the value.
  final String? note;

  /// Resolved checkphrase for an address value.
  ///
  /// Compact paints it under the value; stacked uses a second labeled row.
  final String? checkphrase;

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
    this.checkphrase,
  }) : assert(value != null || valueWidget != null),
       assert(checkphrase == null || valueWidget == null);

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
    this.checkphrase,
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
    final effectiveValueStyle =
        valueStyle ?? (monospace ? text.dataAddress : text.body).copyWith(color: valueColor ?? colors.textContent);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                  child: valueWidget ?? _compactValue(effectiveValueStyle, text, colors),
                ),
              ),
            ],
          ),
          if (note != null) ...[const SizedBox(height: 4), Text(note!, style: _noteStyle(text, colors))],
        ],
      ),
    );
  }

  Widget _compactValue(TextStyle valueStyle, AppTextThemeV3 text, AppColorsV3 colors) {
    final valueText = Text(value!, style: valueStyle, textAlign: TextAlign.right, softWrap: true);
    if (checkphrase == null) return valueText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        valueText,
        Text(
          checkphrase!,
          style: text.caption.copyWith(color: colors.semanticLilac),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _stacked(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;
    final effectiveValueStyle = (monospace ? text.dataAddressLarge : text.body).copyWith(
      color: valueColor ?? colors.textContent,
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: _labelStyle(text, colors)),
          const SizedBox(height: 6),
          Text(value!, style: effectiveValueStyle),
          if (note != null) ...[const SizedBox(height: 4), Text(note!, style: _noteStyle(text, colors))],
          if (checkphrase != null) ...[
            const SizedBox(height: 10),
            Text('$label checkphrase'.toUpperCase(), style: _labelStyle(text, colors)),
            const SizedBox(height: 6),
            Text(checkphrase!, style: effectiveValueStyle.copyWith(color: colors.semanticLilac)),
          ],
        ],
      ),
    );
  }

  TextStyle _labelStyle(AppTextThemeV3 text, AppColorsV3 colors) {
    return text.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: colors.textMuted);
  }

  TextStyle _noteStyle(AppTextThemeV3 text, AppColorsV3 colors) {
    return text.caption.copyWith(color: colors.textMuted);
  }
}
