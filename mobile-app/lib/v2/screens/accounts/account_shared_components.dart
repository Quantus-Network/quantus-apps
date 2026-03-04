import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/glass_icon_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class AccountField extends StatelessWidget {
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  const AccountField({
    super.key,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 8, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class AccountCopyRow extends StatelessWidget {
  final String value;
  final VoidCallback onCopy;
  final TextStyle textStyle;
  final int? maxLines;
  final TextOverflow overflow;

  const AccountCopyRow({
    super.key,
    required this.value,
    required this.onCopy,
    required this.textStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(value, maxLines: maxLines, overflow: overflow, style: textStyle),
        ),
        const SizedBox(width: 8),
        AccountIconActionButton(icon: Icons.copy_outlined, isTiny: true, onTap: onCopy),
      ],
    );
  }
}

class AccountIconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTiny;

  const AccountIconActionButton({super.key, required this.icon, required this.onTap, this.isTiny = false});

  @override
  Widget build(BuildContext context) {
    return GlassIconButton.rounded(
      icon: icon,
      onTap: onTap,
      size: isTiny ? IconButtonSize.small : IconButtonSize.medium,
    );
  }
}

const accountFieldDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.transparent,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  isDense: true,
  contentPadding: EdgeInsets.zero,
);
