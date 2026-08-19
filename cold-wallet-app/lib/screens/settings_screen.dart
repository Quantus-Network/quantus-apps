import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/components/change_password_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setWifiOverride(BuildContext context, WidgetRef ref, bool enabled) async {
    if (!enabled) {
      await ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(false);
      return;
    }
    final confirmed = await showQuantusDialog(
      context,
      title: 'Override network lock?',
      body:
          'A cold wallet is only safe while fully offline — override the lock for testing only, never with a '
          'wallet that holds real funds.',
      actionLabel: 'Override',
      isDestructive: true,
    );
    if (confirmed) await ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(true);
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showQuantusDialog(
      context,
      title: 'Reset wallet?',
      body: 'This erases the encrypted key from this device. You can only restore it with your recovery phrase.',
      actionLabel: 'Reset',
      isDestructive: true,
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
            GestureDetector(
              onTap: () => _confirmReset(context, ref),
              behavior: HitTestBehavior.opaque,
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
