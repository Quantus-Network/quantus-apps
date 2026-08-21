import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Account (or wallet-summary) row matching the v3 Accounts Figma.
///
/// Selected rows are full opacity. Every other row is dimmed. Standalone cards
/// use [bgSurface]; [embedded] rows sit inside a parent card with no extra chrome.
class AccountListRow extends StatelessWidget {
  static const double unselectedOpacity = 0.5;

  final bool isSelected;
  final bool isHighlighted;
  final bool embedded;
  final VoidCallback onTap;
  final Widget leading;
  final String? title;
  final String subtitle;
  final Widget? trailing;
  final Widget? tag;

  const AccountListRow({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.leading,
    required this.subtitle,
    this.isHighlighted = false,
    this.embedded = false,
    this.title,
    this.trailing,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final hasTitle = title != null && title!.isNotEmpty;
    final border = isHighlighted ? Border.all(color: colors.accentFlare, width: 2) : null;

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTitle) ...[
                Text(
                  title!,
                  style: text.amountRow.copyWith(color: colors.textContent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Text(subtitle, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
        if (tag != null) ...[const SizedBox(width: 8), tag!],
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );

    if (!embedded) {
      content = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder, border: border),
        child: content,
      );
    } else if (border != null) {
      content = Container(
        decoration: BoxDecoration(borderRadius: context.radiusV3.mdBorder, border: border),
        child: content,
      );
    }

    if (!isSelected) {
      content = Opacity(opacity: unselectedOpacity, child: content);
    }

    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
  }
}
