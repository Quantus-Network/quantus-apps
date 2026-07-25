import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key, required this.walletIndex});

  final int walletIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

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
          color: colors.surfaceDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderButton, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 20, color: colors.accentOrange),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.homeBackupReminder, style: text.smallParagraph)),
            Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
