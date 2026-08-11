import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/base_background.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Full-screen blocker shown whenever any network is reachable. A cold wallet
/// must stay air-gapped, so this overlays everything and only clears once the
/// device reports it is offline. Fails closed: while connectivity is unknown
/// it stays blocked. Debug and release builds behave identically — the
/// Override setting below is the only way past the lock.
///
/// When the Wi-Fi Lock Override setting is enabled, an Override button leads to
/// an inline confirmation step (this widget sits above the [Navigator] in the
/// [MaterialApp.builder] stack, so dialog routes cannot be shown from here);
/// once confirmed the lock is dismissed for the session and a banner stays on
/// screen so an online signer is never mistaken for an offline one.
///
/// The override is INTENTIONALLY available in release builds: the cold wallet
/// is not yet distributed through app stores, and release builds are tested on
/// real devices where re-toggling radios for every flow costs hours. Do not
/// flag or compile it out — see the note on the Settings screen toggle.
class ConnectivityGuard extends ConsumerStatefulWidget {
  const ConnectivityGuard({super.key});

  @override
  ConsumerState<ConnectivityGuard> createState() => _ConnectivityGuardState();
}

class _ConnectivityGuardState extends ConsumerState<ConnectivityGuard> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(networkStatusProvider, (_, next) {
      final online = next.maybeWhen(data: (s) => s == NetworkStatus.online, orElse: () => true);
      if (!online && _confirming) setState(() => _confirming = false);
    });

    final status = ref.watch(networkStatusProvider);
    final isOnline = status.maybeWhen(data: (s) => s == NetworkStatus.online, orElse: () => true);
    if (!isOnline) return const SizedBox.shrink();

    if (ref.watch(wifiLockOverriddenProvider)) return _relockButton(context);

    return Positioned.fill(
      child: Material(
        color: context.colors.background,
        child: BaseBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _confirming ? _confirmContent(context) : _lockContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockContent(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final overrideAvailable = ref.watch(coldSettingsProvider.select((s) => s.wifiOverrideEnabled));

    return Column(
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
            onTap: () => setState(() => _confirming = true),
          ),
        ],
      ],
    );
  }

  Widget _confirmContent(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.warning_amber_rounded, size: 72, color: colors.error),
        const SizedBox(height: 32),
        Text(
          'Override network lock?',
          style: text.mediumTitle?.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'This device is connected to a network. A cold wallet is only safe while fully offline — override the '
          'lock for testing only, never with a wallet that holds real funds.',
          style: text.paragraph?.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        QuantusButton.simple(
          label: 'Override — I accept the risk',
          onTap: () {
            ref.read(wifiLockOverriddenProvider.notifier).set(true);
            setState(() => _confirming = false);
          },
        ),
        const SizedBox(height: 12),
        QuantusButton.simple(
          label: 'Cancel',
          variant: ButtonVariant.secondary,
          onTap: () => setState(() => _confirming = false),
        ),
      ],
    );
  }

  /// Danger button floating above the bottom safe area: keeps the online state
  /// loudly visible without covering the app's own top or bottom UI. Tapping it
  /// re-arms the lock.
  Widget _relockButton(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      // This sits above the Navigator, outside any Scaffold, so the InkWell
      // inside QuantusButton needs its own Material ancestor.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: QuantusButton.simple(
              label: 'Online — tap to re-lock',
              icon: Icon(Icons.wifi_rounded, size: 18, color: context.colors.textPrimary),
              iconPlacement: IconPlacement.leading,
              variant: ButtonVariant.danger,
              onTap: () => ref.read(wifiLockOverriddenProvider.notifier).set(false),
            ),
          ),
        ),
      ),
    );
  }
}
