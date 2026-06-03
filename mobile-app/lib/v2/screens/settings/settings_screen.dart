import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/generated/version.g.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/about_quantus_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/account_type_settings_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/help_and_support_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/preferences_settings_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';
import 'package:resonance_network_wallet/v2/screens/settings/mining_rewards_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/wallet_settings_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class SettingsScreenV2 extends ConsumerStatefulWidget {
  const SettingsScreenV2({super.key});

  @override
  ConsumerState<SettingsScreenV2> createState() => _SettingsScreenV2State();
}

class _SettingsScreenV2State extends ConsumerState<SettingsScreenV2> {
  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final miningAsync = ref.watch(miningRewardsProvider);

    final colors = context.colors;
    final trailing = SettingsTappableRowUtils.chevron(colors);
    final entries = _settingsHubItems(colors, l10n);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsTitle),
      mainContent: ListView(
        children: [
          for (final e in entries.asMap().entries) ...[
            if (e.value.isMiningRewards)
              miningAsync.when(
                data: (data) => _buildTappableRow(
                  e.value,
                  subtitle: l10n.settingsMiningRewardsSubtitle(data.totalBlocks),
                  trailing: trailing,
                ),
                loading: () => _buildTappableRow(e.value, subtitle: l10n.commonLoading, trailing: trailing),
                error: (err, st) {
                  debugPrint('Error getting mining rewards: ${err.toString()}');
                  debugPrint('Stack trace: ${st.toString()}');

                  return _buildTappableRow(e.value, subtitle: l10n.settingsMiningRewardsError, trailing: trailing);
                },
              )
            else
              _buildTappableRow(e.value, trailing: trailing),
            if (e.key < entries.length - 1) const SettingsDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildTappableRow(_SettingsHubItem item, {required Widget trailing, String? subtitle}) => SettingsTappableRow(
    leading: item.leading,
    title: item.title,
    subtitle: subtitle ?? item.subtitle,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
    trailing: trailing,
  );
}

class _SettingsHubItem {
  const _SettingsHubItem({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.page,
    this.isMiningRewards = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget page;
  final bool isMiningRewards;
}

List<_SettingsHubItem> _settingsHubItems(AppColorsV2 colors, AppLocalizations l10n) {
  return [
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.account_balance_wallet_outlined),
      title: l10n.settingsWalletTitle,
      subtitle: l10n.settingsWalletSubtitle,
      page: const WalletSettingsScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.tune),
      title: l10n.settingsPreferencesTitle,
      subtitle: l10n.settingsPreferencesSubtitle,
      page: const PreferencesSettingsScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, svg: SvgPicture.asset('assets/v2/axe.svg', width: 18, height: 18)),
      title: l10n.settingsMiningRewards,
      subtitle: l10n.commonLoading,
      page: const MiningRewardsScreen(),
      isMiningRewards: true,
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.shield_outlined),
      title: l10n.settingsAccountTypeTitle,
      subtitle: l10n.settingsAccountTypeSubtitle,
      page: const AccountTypeSettingsScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, icon: Icons.help_outline),
      title: l10n.settingsHelpTitle,
      subtitle: l10n.settingsHelpSubtitle,
      page: const HelpAndSupportScreenV2(),
    ),
    _SettingsHubItem(
      leading: _settingsHubIcon(colors, svg: SvgPicture.asset('assets/v2/uppercase_q.svg', width: 18, height: 18)),
      title: l10n.settingsAboutTitle,
      subtitle: l10n.settingsAboutHubSubtitle(appVersion, appBuildNumber),
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
