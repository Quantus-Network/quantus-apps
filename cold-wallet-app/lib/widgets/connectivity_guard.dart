import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/base_background.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Full-screen blocker shown whenever any network is reachable. A cold wallet
/// must stay air-gapped, so this overlays everything and only clears once the
/// device reports it is offline. Fails closed: while connectivity is unknown
/// it stays blocked.
class ConnectivityGuard extends ConsumerWidget {
  const ConnectivityGuard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusProvider);
    final isOnline = status.maybeWhen(data: (s) => s == NetworkStatus.online, orElse: () => true);
    if (!isOnline) return const SizedBox.shrink();

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
