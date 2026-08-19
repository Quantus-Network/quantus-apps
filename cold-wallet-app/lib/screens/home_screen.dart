import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/scan_transaction_screen.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: V2AppBar(
        title: 'Quantus Cold Wallet',
        leading: GestureDetector(
          onTap: () => ref.read(walletControllerProvider.notifier).lock(),
          child: Icon(Icons.lock_outline, color: colors.textContent, size: 22),
        ),
        trailing: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          child: Icon(Icons.settings_outlined, color: colors.textContent, size: 22),
        ),
      ),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Choose an action. This signer stays offline at all times.',
            style: text.body.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _actionCard(
            context,
            icon: Icons.qr_code_2_rounded,
            title: 'Show Key',
            subtitle: 'Display your public address for a hot wallet to scan.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShowKeyScreen())),
          ),
          const SizedBox(height: 16),
          _actionCard(
            context,
            icon: Icons.qr_code_scanner_rounded,
            title: 'Sign Transaction',
            subtitle: 'Scan a transaction, review it, and produce a signature.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanTransactionScreen())),
          ),
        ],
      ),
      bottomContent:
          !(ref.watch(coldSettingsProvider.select((s) => s.wifiOverrideEnabled)) && ref.watch(isOnlineProvider))
          ? null
          : ScaffoldBaseBottomContent(
              child: QuantusButton.simple(
                label: 'Online — tap to re-lock',
                icon: Icon(Icons.wifi_rounded, size: 18, color: colors.textContent),
                iconPlacement: IconPlacement.leading,
                variant: ButtonVariant.danger,
                onTap: () => ref.read(coldSettingsProvider.notifier).setWifiOverrideEnabled(false),
              ),
            ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: context.radiusV3.mdBorder,
          border: Border.all(color: colors.borderHairline, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: context.radiusV3.smBorder),
              child: Icon(icon, color: colors.accentFlare, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.headingRow.copyWith(color: colors.textContent)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.caption.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
