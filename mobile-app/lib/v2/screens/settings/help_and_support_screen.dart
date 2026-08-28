import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';

class HelpAndSupportScreenV2 extends ConsumerWidget {
  const HelpAndSupportScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsHelpScreenTitle),
      mainContent: ListView(
        children: [
          _contactBlock(
            context,
            title: l10n.settingsHelpEmail,
            subtitle: AppConstants.emailSupport,
            onTap: () => openUrl('mailto:${AppConstants.emailSupport}'),
          ),
          _contactBlock(
            context,
            title: l10n.settingsHelpTelegram,
            subtitle: AppConstants.telegramHandle,
            onTap: () => openUrl(AppConstants.communityUrl),
            showBottomDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _contactBlock(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showBottomDivider = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsTappableRow(
          title: title,
          subtitle: subtitle,
          onTap: onTap,
          trailing: SettingsTappableRowUtils.externalLink(context),
        ),
        if (showBottomDivider) const SettingsDivider(),
      ],
    );
  }
}
