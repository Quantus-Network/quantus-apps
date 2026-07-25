import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/reset_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class WalletSettingsScreenV2 extends ConsumerStatefulWidget {
  const WalletSettingsScreenV2({super.key});

  @override
  ConsumerState<WalletSettingsScreenV2> createState() => _WalletSettingsScreenV2State();
}

class _WalletSettingsScreenV2State extends ConsumerState<WalletSettingsScreenV2> {
  void _navigateToRecoveryPhrase(List<Account> accounts) {
    final l10n = ref.read(l10nProvider);
    final walletIndices = getNonHardwareWalletIndices(accounts);
    if (walletIndices.isEmpty) {
      context.showErrorToaster(message: l10n.settingsWalletNoWalletsFound);
      return;
    }

    if (walletIndices.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecoveryPhraseConfirmationScreen(walletIndex: walletIndices.first)),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectWalletScreen()));
    }
  }

  void _showResetConfirmation() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResetConfirmationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final titleColor = colors.textError;
    final subtitleColor = const Color(0xFF67231C);

    final accountsAsync = ref.watch(accountsProvider);

    return ScaffoldBase(
      key: const Key(E2EKeys.walletSettingsScreen),
      appBar: V2AppBar(title: l10n.settingsWalletTitle),
      mainContent: accountsAsync.when(
        loading: () => const Center(child: Loader()),
        error: (e, _) => Center(
          child: Text(l10n.settingsWalletFailedToLoad, style: text.paragraph?.copyWith(color: colors.textSecondary)),
        ),
        data: (accounts) => ListView(
          children: [
            SettingsTappableRow(
              key: const Key(E2EKeys.walletSettingsRecoveryPhraseRow),
              title: l10n.settingsWalletRecoveryPhrase,
              subtitle: l10n.settingsWalletRecoveryPhraseSubtitle,
              onTap: () => _navigateToRecoveryPhrase(accounts),
              trailing: SettingsTappableRowUtils.chevron(colors),
            ),
            const SettingsDivider(style: SettingsDividerStyle.walletSection),
            SettingsTappableRow(
              title: l10n.settingsWalletReset,
              titleColor: titleColor,
              subtitle: l10n.settingsWalletResetSubtitle,
              subtitleColor: subtitleColor,
              onTap: _showResetConfirmation,
              trailing: SettingsTappableRowUtils.chevron(colors, color: titleColor),
            ),
          ],
        ),
      ),
    );
  }
}
