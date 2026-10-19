import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/radio_status_panel.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';
import 'package:quantus_cold_wallet/components/cold_button.dart';
import 'package:quantus_cold_wallet/components/cold_dialog.dart';

/// Full-screen blocker shown whenever any network is reachable (Figma Offline
/// gate). A cold wallet must stay air-gapped, so this overlays everything and
/// only clears once the device reports it is offline. Fails closed: while
/// connectivity is unknown it stays blocked. Debug and release builds behave
/// identically — the Override flow below is the only way past the lock.
///
/// The Override button leads to an [InlineColdDialog] (this widget sits
/// above the [Navigator] in the [MaterialApp.builder] stack, so dialog routes
/// cannot be shown from here); confirming enables the persistent Wi-Fi Lock
/// Override setting and dismisses the lock. While overridden this guard
/// renders nothing; the Settings screen toggle switches the override back off.
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

  void _override() {
    ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(true);
    setState(() => _confirming = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isOnlineProvider, (_, online) {
      if (!online && _confirming) setState(() => _confirming = false);
    });

    if (!ref.watch(isOnlineProvider)) return const SizedBox.shrink();

    if (ref.watch(coldSettingsProvider.select((s) => s.wifiOverrideEnabled))) return const SizedBox.shrink();

    final colors = context.colorsV3;
    return Positioned.fill(
      child: Material(
        color: colors.bgVoid,
        child: Stack(
          children: [
            _Gate(onOverride: () => setState(() => _confirming = true)),
            if (_confirming)
              InlineColdDialog(
                dialog: ColdDialog(
                  title: 'Sign while online?',
                  titleColor: colors.semanticEmber,
                  body:
                      "A signer is only safe while it's fully offline. Anything you approve from here could be "
                      'exposed. For testing only, never with a key that holds real funds.',
                  actionLabel: 'Override, I accept the risk',
                  isDestructive: true,
                  onAction: _override,
                  onCancel: () => setState(() => _confirming = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Gate extends ConsumerWidget {
  final VoidCallback onOverride;

  const _Gate({required this.onOverride});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final onboarding = ref.watch(walletControllerProvider.select((s) => s.status == WalletStatus.needsSetup));
    final results = ref
        .watch(connectivityResultsProvider)
        .when(
          data: (r) => r,
          loading: () => const <ConnectivityResult>[],
          error: (e, st) => Error.throwWithStackTrace(e, st),
        );

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: ScaffoldBase.defaultPadding,
            child: V2AppBar(title: 'Network Detected', showBackButton: false),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: ScaffoldBase.defaultPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 83),
                  Center(child: ColdIcon(ColdIcons.wifiSlash, size: 60, color: colors.accentFlare)),
                  const SizedBox(height: 24),
                  Text(
                    onboarding ? 'Go offline to continue' : 'Waiting for you to go offline',
                    style: text.titleHero.copyWith(color: colors.textContent, height: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    onboarding
                        ? 'No key is created while this phone is connected.'
                        : "A signer can't unlock while it's connected.",
                    style: text.bodyLarge.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  RadioStatusPanel(results: results),
                  const SizedBox(height: 16),
                  Text(
                    "Switch Wi-Fi, cellular and Bluetooth off in your phone's settings. The list shows active "
                    "connections, not whether a radio is on. It clears itself the moment you're fully offline.",
                    style: text.caption.copyWith(color: colors.textMuted2, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          ScaffoldBaseBottomContent(
            child: ColdButton.secondary(label: 'Override for Testing', onTap: onOverride),
          ),
        ],
      ),
    );
  }
}
