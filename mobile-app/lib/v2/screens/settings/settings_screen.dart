import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/generated/version.g.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/about_quantus_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/account_type_settings_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/help_and_support_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/preferences_settings_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';
import 'package:resonance_network_wallet/v2/screens/settings/wallet_settings_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class SettingsScreenV2 extends StatelessWidget {
  const SettingsScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trailing = SettingsTappableRowUtils.chevron(colors);
    final entries = _settingsHubItems(colors);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Settings'),
      mainContent: ListView(
        children: [
          for (final e in entries.asMap().entries) ...[
            SettingsTappableRow(
              leading: e.value.leading,
              title: e.value.title,
              subtitle: e.value.subtitle,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => e.value.page)),
              trailing: trailing,
            ),
            if (e.key < entries.length - 1) const SettingsDivider(),
          ],
        ],
      ),
    );
  }
}

class _SettingsHubItem {
  const _SettingsHubItem({required this.leading, required this.title, required this.subtitle, required this.page});

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget page;
}

List<_SettingsHubItem> _settingsHubItems(AppColorsV2 colors) {
  return [
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.account_balance_wallet_outlined),
      title: 'Wallet',
      subtitle: 'Recovery Phrase, Reset Wallet',
      page: const WalletSettingsScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.tune),
      title: 'Preferences',
      subtitle: 'Currency, POS mode, notifications',
      page: const PreferencesSettingsScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.shield_outlined),
      title: 'Account Type',
      subtitle: 'Advanced Account Features',
      page: const AccountTypeSettingsScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.help_outline),
      title: 'Help & Support',
      subtitle: 'FAQs, Contact the team',
      page: const HelpAndSupportScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, svg: SvgPicture.asset('assets/v2/uppercase_q.svg', width: 18, height: 18)),
      title: 'About Quantus',
      subtitle: 'Version $appVersion ($appBuildNumber)',
      page: const AboutQuantusScreenV2(),
    ),
  ];
}

/// 40×40 leading slot: [icon] in accent orange, or a custom [svg].
Widget _settingsHubIcon(AppColorsV2 colors, {IconData? icon, SvgPicture? svg}) {
  const double iconSlot = 40;
  Widget? child;

  if (icon != null) {
    child = Icon(icon, color: colors.accentOrange, size: 22);
  } else if (svg != null) {
    child = svg;
  }

  return SizedBox(
    width: iconSlot,
    height: iconSlot,
    child: Center(child: child),
  );
}
