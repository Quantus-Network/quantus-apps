import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';

/// Full-screen blocker shown whenever any network is reachable. A cold wallet
/// must stay air-gapped, so this overlays everything and only clears once the
/// device reports it is offline. Fails closed: while connectivity is unknown
/// it stays blocked. Debug and release builds behave identically — the
/// Override flow below is the only way past the lock.
///
/// The Override button leads to an inline confirmation step (this widget sits
/// above the [Navigator] in the [MaterialApp.builder] stack, so dialog routes
/// cannot be shown from here); confirming enables the persistent Wi-Fi Lock
/// Override setting and dismisses the lock. While overridden this guard
/// renders nothing — the home screen shows a red re-lock button that switches
/// the setting back off, and the Settings screen has the same toggle.
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
    ref.listen(isOnlineProvider, (_, online) {
      if (!online && _confirming) setState(() => _confirming = false);
    });

    if (!ref.watch(isOnlineProvider)) return const SizedBox.shrink();

    if (ref.watch(coldSettingsProvider.select((s) => s.wifiOverrideEnabled))) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: context.colorsV3.bgVoid,
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off_rounded, size: 72, color: colors.semanticSand),
        const SizedBox(height: 32),
        Text(
          'Network detected',
          style: text.titleScreen.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'This is a cold wallet and must stay offline. Turn on Airplane Mode and disable Wi-Fi, cellular, '
          'Bluetooth and any other connections to continue.',
          style: text.body.copyWith(color: colors.textMuted, height: 1.55),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Text(
          'The signer will unlock automatically once the device is fully offline.',
          style: text.caption.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        QuantusButton.simple(
          label: 'Override for testing',
          variant: ButtonVariant.staged,
          onTap: () => setState(() => _confirming = true),
        ),
      ],
    );
  }

  Widget _confirmContent(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.warning_amber_rounded, size: 72, color: colors.semanticEmber),
        const SizedBox(height: 32),
        Text(
          'Override network lock?',
          style: text.titleScreen.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'This device is connected to a network. A cold wallet is only safe while fully offline — override the '
          'lock for testing only, never with a wallet that holds real funds.',
          style: text.body.copyWith(color: colors.textMuted, height: 1.55),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        QuantusButton.simple(
          label: 'Override — I accept the risk',
          variant: ButtonVariant.danger,
          onTap: () {
            ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(true);
            setState(() => _confirming = false);
          },
        ),
        const SizedBox(height: 12),
        QuantusButton.simple(
          label: 'Cancel',
          variant: ButtonVariant.staged,
          onTap: () => setState(() => _confirming = false),
        ),
      ],
    );
  }
}
