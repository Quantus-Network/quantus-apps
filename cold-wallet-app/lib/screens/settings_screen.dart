import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/show_secret_phrase_screen.dart';
import 'package:quantus_cold_wallet/components/cold_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setWifiOverride(BuildContext context, WidgetRef ref, bool enabled) async {
    if (!enabled) {
      await ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(false);
      return;
    }
    final confirmed = await showColdDialog(
      context,
      title: 'Override network lock?',
      titleColor: context.colorsV3.semanticEmber,
      body:
          'A cold wallet is only safe while fully offline — override the lock for testing only, never with a '
          'wallet that holds real funds.',
      actionLabel: 'Override',
      isDestructive: true,
    );
    if (confirmed) await ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(true);
  }

  Future<void> _showSecretPhrase(BuildContext context, WidgetRef ref) async {
    final bool confirmed;
    try {
      confirmed = await ref.read(walletControllerProvider.notifier).confirmPresence();
    } catch (e, st) {
      debugPrint('Show secret phrase: presence check failed: $e\n$st');
      if (context.mounted) context.showErrorToaster(message: 'Could not read the signing key: $e');
      return;
    }
    if (!context.mounted) return;
    if (!confirmed) {
      context.showInfoToaster(message: 'Could not confirm it is you.');
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShowSecretPhraseScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final settings = ref.watch(coldSettingsProvider);
    final protection = ref.watch(keyProtectionProvider).value;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Settings'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const _SectionLabel('SECURITY'),
            _SettingsCard(
              title: 'Unlock method',
              subtitle: switch (protection) {
                null => 'Checking the signing key…',
                KeyProtection.userPresence =>
                  'Face ID or passcode. This device releases the signing key only after you confirm it is you.',
                KeyProtection.upgradePending =>
                  'None yet. This phone has a device lock now, so the signing key moves behind Face ID or passcode '
                      'at your next unlock.',
                KeyProtection.legacyPrompt =>
                  'Device prompt. This phone cannot keep the signing key behind user presence, so the app asks you '
                      'to confirm it is you before each use.',
                KeyProtection.none =>
                  'None. This phone has no device lock, so the signing key is stored without user presence.',
              },
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Show secret phrase',
              subtitle: 'Reveal the recovery phrase for this wallet. Confirm it is you first.',
              onTap: () => _showSecretPhrase(context, ref),
            ),
            const SizedBox(height: 12),
            // INTENTIONAL: this override ships in RELEASE builds. The cold wallet is
            // not yet distributed through app stores, and testing release builds on
            // real devices without it means toggling Wi-Fi/airplane mode for every
            // flow. The lock stays fail-closed by default: enabling the override —
            // here or from the network lock screen — always passes through an
            // explicit danger warning, and it is switched off again here or by
            // going offline. Do not "fix" this by compiling it out of release
            // builds; revisit only when the app ships to app-store users.
            _SettingsCard(
              title: 'Wi-Fi Lock Override (debugging only)',
              subtitle:
                  'For debugging only — disables the network lock so the signer can be used while online. '
                  'Not safe: never use this with a wallet that holds real funds.',
              trailing: Switch(
                value: settings.wifiOverrideEnabled,
                activeTrackColor: colors.accentFlare,
                onChanged: (v) => _setWifiOverride(context, ref, v),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionLabel('SIGNATURE QR'),
            Text(
              'How the animated signature QR is displayed. Higher values transfer faster but are harder to scan.',
              style: text.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 16),
            const QrTuningControls(),
            const SizedBox(height: 32),
            const _SectionLabel('DANGER ZONE'),
            _SettingsCard(
              title: 'Reset wallet',
              subtitle: 'Erase the encrypted key and its device-protected unlock key from this phone.',
              titleColor: colors.semanticEmber,
              onTap: () => confirmResetWallet(context, ref),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(label, style: context.themeTextV3.labelMonogram.copyWith(color: context.colorsV3.textMuted)),
  );
}

/// One settings row on a surface card: a title, its explanation and either a
/// chevron (tappable), a control, or nothing (read-only).
class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsCard({required this.title, required this.subtitle, this.titleColor, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: context.radiusV3.mdBorder,
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.headingRow.copyWith(color: titleColor ?? colors.textContent)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.caption.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            if (onTap != null) ...[
              const SizedBox(width: 12),
              QuantusIcon(QuantusIcons.chevronRight, size: 20, color: colors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
