import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';

class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key, required this.walletIndex});

  final int walletIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecoveryPhraseConfirmationScreen(walletIndex: walletIndex, showAlreadyBackedUp: true),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: context.radiusV3.mdBorder,
          border: Border.all(color: colors.borderHairline, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 20, color: colors.semanticSand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.homeBackupReminder, style: text.body.copyWith(color: colors.textContent)),
            ),
            const QuantusIcon(QuantusIcons.chevronRight),
          ],
        ),
      ),
    );
  }
}
