import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/offline_pill.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Create or Import (Figma 798:6187).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final online = ref.watch(isOnlineProvider);

    return ScaffoldBase(
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          QuantusIcon(QuantusIcons.lock, size: 60, color: colors.accentFlare),
          const SizedBox(height: 24),
          Text(
            'Quantus Cold Wallet',
            style: text.titleHero.copyWith(color: colors.textContent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your keys stay on this device.\nSigning happens over QR.',
            style: text.bodyLarge.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          if (!online) const OfflinePill(),
          const SizedBox(height: 24),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(
              label: 'Create New Key',
              padding: coldButtonPadding,
              onTap: () => _push(context, const CreateWalletScreen()),
            ),
            const SizedBox(height: 12),
            QuantusButton.simple(
              label: 'Import Key',
              variant: ButtonVariant.secondary,
              padding: coldButtonPadding,
              onTap: () => _push(context, const ImportWalletScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
