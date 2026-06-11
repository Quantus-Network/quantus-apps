import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/scan_transaction_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.sheetBackground,
        title: const Text('Reset wallet?'),
        content: const Text(
          'This erases the encrypted key from this device. You can only restore it with your recovery phrase.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(walletControllerProvider.notifier).wipe();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: V2AppBar(
        title: 'Quantus Cold Wallet',
        leading: GestureDetector(
          onTap: () => ref.read(walletControllerProvider.notifier).lock(),
          child: Icon(Icons.lock_outline, color: colors.textPrimary, size: 22),
        ),
        trailing: GestureDetector(
          onTap: () => _confirmReset(context, ref),
          child: Icon(Icons.more_horiz, color: colors.textPrimary, size: 22),
        ),
      ),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Choose an action. This signer stays offline at all times.',
            style: text.smallParagraph?.copyWith(color: colors.textSecondary),
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
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final text = context.themeText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderButton, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: colors.accentOrange, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.detail?.copyWith(color: colors.textSecondary)),
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
