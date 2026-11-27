import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/notice_box.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// Reminds to back up the recovery phrase of the wallet at [walletIndex], as
/// the phone's home does; Back Up opens Settings on that phrase, where it can
/// also be said to be backed up already.
class BackupReminder extends ConsumerWidget {
  const BackupReminder({super.key, required this.walletIndex});

  static const backUpKey = Key('backup-reminder-back-up');

  final int walletIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    // The mark is in the row rather than the box's, so it stays level with
    // the line beside the taller button.
    return NoticeBox(
      tone: colors.semanticSand,
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 13, color: colors.semanticSand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.homeBackupReminder, style: text.body.copyWith(color: colors.textContent)),
          ),
          const SizedBox(width: 12),
          SheetButton(
            key: backUpKey,
            label: l10n.desktopBackupReminderButton,
            kind: SheetButtonKind.secondary,
            onTap: () => ref.read(accountManagerProvider).openRecoveryPhrase(walletIndex, fromBackupReminder: true),
          ),
        ],
      ),
    );
  }
}
