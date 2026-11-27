import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// Where to get help, as the phone's Help & Support has it: Discord, with the
/// warning that support never writes first, and Telegram. Each opens in the
/// browser.
class HelpSupportSheet extends ConsumerWidget {
  const HelpSupportSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    void open(String url) => unawaited(ref.read(openExternalUrlProvider)(Uri.parse(url)));

    return SettingsGroup(
      rows: [
        SettingsRow.action(
          title: l10n.settingsHelpDiscord,
          subtitle: l10n.commonSupportScamWarning,
          onPressed: () => open(AppConstants.discordSupportUrl),
        ),
        SettingsRow.action(
          title: l10n.settingsHelpTelegram,
          subtitle: AppConstants.telegramHandle,
          onPressed: () => open(AppConstants.communityUrl),
        ),
      ],
    );
  }
}
