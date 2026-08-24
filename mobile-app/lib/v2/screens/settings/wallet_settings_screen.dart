import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/reset_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';

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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final destructiveColor = colors.semanticEmber;

    final accountsAsync = ref.watch(accountsProvider);

    return ScaffoldBase(
      key: const Key(E2EKeys.walletSettingsScreen),
      appBar: V2AppBar(title: l10n.settingsWalletTitle),
      mainContent: accountsAsync.when(
        loading: () => const Center(child: Loader()),
        error: (e, _) => Center(
          child: Text(l10n.settingsWalletFailedToLoad, style: text.body.copyWith(color: colors.textMuted)),
        ),
        data: (accounts) => ListView(
          children: [
            SettingsTappableRow(
              key: const Key(E2EKeys.walletSettingsRecoveryPhraseRow),
              title: l10n.settingsWalletRecoveryPhrase,
              subtitle: l10n.settingsWalletRecoveryPhraseSubtitle,
              onTap: () => _navigateToRecoveryPhrase(accounts),
              trailing: SettingsTappableRowUtils.chevron(),
            ),
            const SettingsDivider(),
            SettingsTappableRow(
              title: l10n.settingsWalletReset,
              titleColor: destructiveColor,
              subtitle: l10n.settingsWalletResetSubtitle,
              onTap: _showResetConfirmation,
              trailing: SettingsTappableRowUtils.chevron(color: destructiveColor),
            ),
          ],
        ),
      ),
    );
  }
}
