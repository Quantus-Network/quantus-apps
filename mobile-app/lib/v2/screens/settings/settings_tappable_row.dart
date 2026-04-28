import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

abstract final class SettingsTappableRowUtils {
  static TextStyle? title(AppTextTheme text, AppColorsV2 colors, {Color? color}) {
    return text.smallTitle?.copyWith(fontWeight: FontWeight.w400, color: color ?? colors.textPrimary);
  }

  static TextStyle? subtitle(AppTextTheme text, AppColorsV2 colors, {Color? color}) {
    return text.smallParagraph?.copyWith(color: color ?? colors.textTertiary);
  }

  static Widget externalLink(AppColorsV2 colors) {
    return Icon(Icons.north_east, size: 14, color: colors.textLabel);
  }

  static Widget chevron(AppColorsV2 colors, {double size = 14, Color? color}) {
    return Icon(Icons.chevron_right, size: size, color: color ?? colors.textSecondary);
  }

  static const Widget titleGap = SizedBox(height: 2);

  static Widget titleAndSubtitle(String title, String subtitle, AppTextTheme text, AppColorsV2 colors) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: SettingsTappableRowUtils.title(text, colors)),
          SettingsTappableRowUtils.titleGap,
          Text(subtitle, style: SettingsTappableRowUtils.subtitle(text, colors)),
        ],
      ),
    );
  }
}

/// Title + subtitle cell with optional [leading], custom styles, and trailing control.
class SettingsTappableRow extends StatelessWidget {
  const SettingsTappableRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
    this.titleColor,
    this.subtitleColor,
    this.leading,
    this.padding,
  });

  final String title;
  final Color? titleColor;

  final String subtitle;
  final Color? subtitleColor;

  final VoidCallback onTap;
  final Widget trailing;

  final Widget? leading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        SettingsTappableRowUtils.titleAndSubtitle(title, subtitle, text, colors),
        trailing,
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: padding != null ? Padding(padding: padding!, child: row) : row,
      ),
    );
  }
}

/// Title + subtitle with a [CupertinoSwitch] — no full-row ink splash (toggle handles interaction).
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SettingsTappableRowUtils.titleAndSubtitle(title, subtitle, text, colors),
        CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: colors.accentGreen),
      ],
    );
  }
}
