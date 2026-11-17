import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_caution.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/user_approval.dart';

/// Resetting the wallet: the caution, a box to tick once the phrase is
/// backed up, and Reset Wallet, which asks for approval, wipes the wallet
/// from this computer and closes the sheet on Welcome.
class ResetWalletStep extends ConsumerStatefulWidget {
  const ResetWalletStep({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  ConsumerState<ResetWalletStep> createState() => _ResetWalletStepState();
}

class _ResetWalletStepState extends ConsumerState<ResetWalletStep> {
  bool _isBackedUp = false;
  bool _isBusy = false;
  String? _error;

  Future<void> _reset() async {
    final l10n = ref.read(l10nProvider);
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final refusal = await askForApproval(
      ref.read(userApprovalProvider),
      l10n,
      reason: l10n.settingsResetAuthReason,
      declined: l10n.settingsResetAuthRequired,
    );
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _isBusy = false;
        _error = refusal;
      });
      return;
    }

    try {
      await ref.read(walletPresenceProvider.notifier).wipeWallet();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _error = l10n.settingsResetFailed('$e');
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCaution(
          eyebrow: l10n.desktopResetEyebrow,
          // Mobile breaks the line for a phone's width; the sheet has room.
          headline: l10n.settingsResetCautionHeadline.replaceAll('\n', ' '),
          lines: [l10n.settingsResetCautionBullet1, l10n.settingsResetCautionBullet2, l10n.settingsResetCautionBullet3],
        ),
        const SizedBox(height: 6),
        DesktopCheckbox(
          key: SettingsSheet.backupCheckboxKey,
          value: _isBackedUp,
          label: l10n.settingsResetCautionCheckbox,
          onChanged: _isBusy ? (_) {} : (value) => setState(() => _isBackedUp = value),
        ),
        const SizedBox(height: 22),
        SettingsStepFooter(
          error: _error,
          buttons: [
            SheetButton(
              key: SettingsSheet.cancelKey,
              label: l10n.commonCancel,
              kind: SheetButtonKind.secondary,
              onTap: widget.onCancel,
            ),
            SheetButton(
              key: SettingsSheet.resetButtonKey,
              label: l10n.settingsWalletReset,
              kind: SheetButtonKind.destructive,
              isDisabled: !_isBackedUp,
              isLoading: _isBusy,
              onTap: _reset,
            ),
          ],
        ),
      ],
    );
  }
}
