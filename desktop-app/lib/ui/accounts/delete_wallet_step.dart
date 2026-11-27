import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_session.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_caution.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/services/user_approval.dart';

/// Deleting a wallet and its recovery phrase from this app: the caution for
/// what goes, [firstLine] saying which accounts, then Delete Wallet. That
/// waits for a tick that the phrase is backed up, and asks for the system's
/// approval where the computer can ask, going ahead where it cannot, as the
/// phone does. A deletion that is refused or fails says why, and the step
/// stays.
class DeleteWalletStep extends ConsumerStatefulWidget {
  const DeleteWalletStep({
    super.key,
    required this.wallet,
    required this.firstLine,
    required this.delete,
    required this.onCancel,
    required this.onDeleted,
    required this.l10n,
    required this.backedUpKey,
    required this.cancelKey,
    required this.deleteKey,
  });

  /// What the wallet is called.
  final String wallet;

  /// The caution's first line: the accounts that go with the wallet.
  final String firstLine;

  /// Deletes the wallet, once approved. It throws when it cannot, and the
  /// wallet is then whole.
  final Future<void> Function() delete;
  final VoidCallback onCancel;
  final VoidCallback onDeleted;
  final AppLocalizations l10n;

  final Key backedUpKey;
  final Key cancelKey;
  final Key deleteKey;

  @override
  ConsumerState<DeleteWalletStep> createState() => _DeleteWalletStepState();
}

class _DeleteWalletStepState extends ConsumerState<DeleteWalletStep> {
  bool _isBackedUp = false;
  bool _isBusy = false;
  String? _error;

  /// Null once the deletion may go ahead; otherwise why not.
  Future<String?> _approveDeletion() async {
    final l10n = widget.l10n;
    final wallet = widget.wallet;
    try {
      return switch (await ref.read(userApprovalProvider).approve(reason: l10n.desktopDisconnectWalletReason(wallet))) {
        // A computer that cannot ask has nothing to enforce: the phone goes
        // ahead on a device with no lock screen.
        ApprovalResult.approved || ApprovalResult.notSetUp => null,
        ApprovalResult.declined => l10n.desktopDisconnectWalletDeclined(wallet),
      };
    } on PamUnexpectedPromptException {
      return l10n.desktopApprovalLoginAsksMore;
    } catch (e) {
      return l10n.desktopApprovalFailed('$e');
    }
  }

  Future<void> _delete() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final refusal = await _approveDeletion();
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _isBusy = false;
        _error = refusal;
      });
      return;
    }
    try {
      await widget.delete();
    } catch (e) {
      quantusPrint('Deleting ${widget.wallet} failed: $e');
      if (mounted) {
        setState(() {
          _isBusy = false;
          _error = widget.l10n.accountMenuDisconnectError;
        });
      }
      return;
    }
    if (mounted) widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final wallet = widget.wallet;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCaution(
          eyebrow: l10n.desktopResetEyebrow,
          headline: l10n.desktopDisconnectWalletHeadline(wallet),
          lines: [widget.firstLine, l10n.desktopDisconnectWalletLine2(wallet), l10n.desktopDisconnectWalletLine3],
        ),
        const SizedBox(height: 6),
        DesktopCheckbox(
          key: widget.backedUpKey,
          value: _isBackedUp,
          label: l10n.desktopDisconnectWalletBackedUp(wallet),
          onChanged: _isBusy ? (_) {} : (value) => setState(() => _isBackedUp = value),
        ),
        const SizedBox(height: 22),
        SettingsStepFooter(
          error: _error,
          buttons: [
            SheetButton(
              key: widget.cancelKey,
              label: l10n.commonCancel,
              kind: SheetButtonKind.secondary,
              onTap: widget.onCancel,
            ),
            SheetButton(
              key: widget.deleteKey,
              label: l10n.accountMenuDeleteWalletConfirm,
              kind: SheetButtonKind.destructive,
              isDisabled: !_isBackedUp,
              isLoading: _isBusy,
              onTap: _delete,
            ),
          ],
        ),
      ],
    );
  }
}
