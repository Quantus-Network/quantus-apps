import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Label/value row used in review screens and detail sheets.
class DetailSummaryRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final int labelFlex;
  final int valueFlex;
  final EdgeInsetsGeometry padding;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

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

  @override
  Widget build(BuildContext context) {
    final text = context.themeText;
    final colors = context.colors;
    final effectiveLabelStyle = labelStyle ?? text.transactionDetailRowLabel?.copyWith(color: colors.textTertiary);
    final effectiveValueStyle =
        valueStyle ?? text.transactionDetailRowValue?.copyWith(color: Colors.white.withValues(alpha: 0.8));

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
}
