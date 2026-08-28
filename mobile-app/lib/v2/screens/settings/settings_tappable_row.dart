import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

abstract final class SettingsTappableRowUtils {
  static TextStyle title(BuildContext context, {Color? color}) {
    return context.themeTextV3.amountRow.copyWith(color: color ?? context.colorsV3.textContent);
  }

  static TextStyle subtitle(BuildContext context, {Color? color}) {
    return context.themeTextV3.caption.copyWith(color: color ?? context.colorsV3.textMuted);
  }

  static Widget externalLink(BuildContext context) {
    return Icon(Icons.north_east, size: 14, color: context.colorsV3.textMuted);
  }

  static Widget chevron({Color? color}) {
    return QuantusIcon(QuantusIcons.chevronRight, color: color);
  }

  static const Widget titleGap = SizedBox(height: 2);

  static Widget titleAndSubtitle(
    BuildContext context,
    String title,
    String subtitle, {
    Color? titleColor,
    Color? subtitleColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: SettingsTappableRowUtils.title(context, color: titleColor)),
          SettingsTappableRowUtils.titleGap,
          Text(subtitle, style: SettingsTappableRowUtils.subtitle(context, color: subtitleColor)),
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
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        SettingsTappableRowUtils.titleAndSubtitle(
          context,
          title,
          subtitle,
          titleColor: titleColor,
          subtitleColor: subtitleColor,
        ),
        trailing,
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.radiusV3.mdBorder,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SettingsTappableRowUtils.titleAndSubtitle(context, title, subtitle),
        CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: context.colorsV3.accentFlare),
      ],
    );
  }
}
