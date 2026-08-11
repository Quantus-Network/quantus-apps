import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/confirm_dialog.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';
import 'package:quantus_cold_wallet/widgets/change_password_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
            GestureDetector(
              onTap: () => showChangePasswordSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change password', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          'Set or change the password that encrypts the wallet key on this device.',
                          style: text.detail?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textMuted, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // INTENTIONAL: this override ships in RELEASE builds. The cold wallet is
            // not yet distributed through app stores, and testing release builds on
            // real devices without it means toggling Wi-Fi/airplane mode for every
            // flow. The lock stays fail-closed by default: the Override button only
            // exists behind this persistent opt-in, an override lasts one session,
            // and a red banner stays on screen while it is active. Do not "fix" this
            // by compiling it out of release builds; revisit only when the app ships
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
                        'For debugging only — shows an Override button on the network lock screen so it can be '
                        'dismissed while testing. Not safe: never use this with a wallet that holds real funds.',
                        style: text.detail?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: settings.wifiOverrideEnabled,
                  activeTrackColor: colors.accentOrange,
                  onChanged: (v) => ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(v),
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
            GestureDetector(
              onTap: () => _confirmReset(context, ref),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reset wallet', style: text.smallParagraph?.copyWith(color: colors.error)),
                        const SizedBox(height: 4),
                        Text(
                          'Erase the encrypted key from this device.',
                          style: text.detail?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textMuted, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
