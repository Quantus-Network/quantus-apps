import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/base_background.dart';
import 'package:quantus_cold_wallet/components/confirm_dialog.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Full-screen blocker shown whenever any network is reachable. A cold wallet
/// must stay air-gapped, so this overlays everything and only clears once the
/// device reports it is offline. Fails closed: while connectivity is unknown
/// it stays blocked.
///
/// When the Wi-Fi Lock Override setting is enabled, an Override button lets the
/// lock be dismissed for the session after a warning; while dismissed a banner
/// stays on screen so an online signer is never mistaken for an offline one.
///
/// The override is INTENTIONALLY available in release builds: the cold wallet
/// is not yet distributed through app stores, and release builds are tested on
/// real devices where re-toggling radios for every flow costs hours. Do not
/// flag or compile it out — see the note on the Settings screen toggle.
class ConnectivityGuard extends ConsumerWidget {
  const ConnectivityGuard({super.key});

  Future<void> _confirmOverride(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Override network lock?',
      message:
          'This device is connected to a network. A cold wallet is only safe while fully offline — override the '
          'lock for testing only, never with a wallet that holds real funds.',
      confirmLabel: 'Override',
    );
    if (confirmed) ref.read(wifiLockOverriddenProvider.notifier).set(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDebugMode) return const SizedBox.shrink();

    final status = ref.watch(networkStatusProvider);
    final isOnline = status.maybeWhen(data: (s) => s == NetworkStatus.online, orElse: () => true);
    if (!isOnline) return const SizedBox.shrink();

    if (ref.watch(wifiLockOverriddenProvider)) return _overriddenBanner(context, ref);

    final overrideAvailable = ref.watch(coldSettingsProvider.select((s) => s.wifiOverrideEnabled));
    final colors = context.colors;
    final text = context.themeText;

    return Positioned.fill(
      child: Material(
        color: colors.background,
        child: BaseBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 72, color: colors.accentOrange),
                  const SizedBox(height: 32),
                  Text(
                    'Network detected',
                    style: text.mediumTitle?.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This is a cold wallet and must stay offline. Turn on Airplane Mode and disable Wi-Fi, cellular, '
                    'Bluetooth and any other connections to continue.',
                    style: text.paragraph?.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'The signer will unlock automatically once the device is fully offline.',
                    style: text.detail?.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  if (overrideAvailable) ...[
                    const SizedBox(height: 32),
                    QuantusButton.simple(
                      label: 'Override for testing',
                      variant: ButtonVariant.secondary,
                      onTap: () => _confirmOverride(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Thin strip over the status bar area: keeps the online state loudly visible
  /// without covering the app. Tapping it re-arms the lock.
  Widget _overriddenBanner(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final topInset = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => ref.read(wifiLockOverriddenProvider.notifier).set(false),
        child: Container(
          color: colors.error,
          padding: EdgeInsets.only(top: topInset > 0 ? topInset : 8, bottom: 4),
          child: Text(
            'Online — lock overridden. Tap to re-lock.',
            style: text.detail?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
