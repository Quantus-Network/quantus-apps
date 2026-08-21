import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/confirm_dialog.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/show_secret_phrase_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';
import 'package:quantus_cold_wallet/widgets/change_password_sheet.dart';
import 'package:quantus_cold_wallet/widgets/verify_password_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setWifiOverride(BuildContext context, WidgetRef ref, bool enabled) async {
    if (!enabled) {
      await ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(false);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Override network lock?',
      message:
          'A cold wallet is only safe while fully offline — override the lock for testing only, never with a '
          'wallet that holds real funds.',
      confirmLabel: 'Override',
    );
    if (confirmed) await ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(true);
  }

  Future<void> _showSecretPhrase(BuildContext context) async {
    final verified = await showVerifyPasswordSheet(
      context,
      message: 'Your password is required to show the secret phrase.',
    );
    if (!verified || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShowSecretPhraseScreen()));
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reset wallet?',
      message: 'This erases the encrypted key from this device. You can only restore it with your recovery phrase.',
      confirmLabel: 'Reset',
    );
    if (!confirmed) return;
    await ref.read(walletControllerProvider.notifier).wipe();
    if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final settings = ref.watch(coldSettingsProvider);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Settings'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text('SECURITY', style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
            const SizedBox(height: 8),
            _navRow(
              context,
              title: 'Change password',
              subtitle: 'Set or change the password that encrypts the wallet key on this device.',
              onTap: () => showChangePasswordSheet(context),
            ),
            const SizedBox(height: 24),
            _navRow(
              context,
              title: 'Show secret phrase',
              subtitle: 'Reveal the recovery phrase for this wallet. Your password is required.',
              onTap: () => _showSecretPhrase(context),
            ),
            const SizedBox(height: 24),
            // INTENTIONAL: this override ships in RELEASE builds. The cold wallet is
            // not yet distributed through app stores, and testing release builds on
            // real devices without it means toggling Wi-Fi/airplane mode for every
            // flow. The lock stays fail-closed by default: enabling the override —
            // here or from the network lock screen — always passes through an
            // explicit danger warning, and while it is active the home screen shows
            // a red re-lock button that switches it back off. Do not "fix" this by
            // compiling it out of release builds; revisit only when the app ships
            // to app-store users.
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wi-Fi Lock Override (debugging only)',
                        style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'For debugging only — disables the network lock so the signer can be used while online. '
                        'Not safe: never use this with a wallet that holds real funds.',
                        style: text.detail?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: settings.wifiOverrideEnabled,
                  activeTrackColor: colors.accentOrange,
                  onChanged: (v) => _setWifiOverride(context, ref, v),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: colors.borderButton),
            const SizedBox(height: 16),
            Text('SIGNATURE QR', style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
            const SizedBox(height: 8),
            Text(
              'How the animated signature QR is displayed. Higher values transfer faster but are harder to scan.',
              style: text.detail?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            const QrTuningControls(),
            const SizedBox(height: 24),
            Divider(color: colors.borderButton),
            const SizedBox(height: 16),
            Text('DANGER ZONE', style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
            const SizedBox(height: 8),
            _navRow(
              context,
              title: 'Reset wallet',
              subtitle: 'Erase the encrypted key from this device.',
              titleColor: colors.error,
              onTap: () => _confirmReset(context, ref),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _navRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    final colors = context.colors;
    final text = context.themeText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.smallParagraph?.copyWith(color: titleColor ?? colors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: text.detail?.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textMuted, size: 22),
        ],
      ),
    );
  }
}
