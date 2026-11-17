import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/recovery_phrase_grid.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_caution.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/recovery_phrase.dart';

/// The wallet whose recovery phrase Settings shows. A desktop holds one
/// software wallet for now, the first on the device; choosing between
/// wallets comes with adding them.
const _walletIndex = 0;

/// Records that the recovery phrase has been seen, as mobile does when it is
/// revealed or copied. It takes the app's [container] rather than a widget's
/// ref, so a copy that completes after the sheet has closed is still recorded.
void _markPhraseSeen(ProviderContainer container) {
  container.read(settingsServiceProvider).setRecoveryPhraseViewed(_walletIndex);
  container.invalidate(recoveryPhraseViewedProvider(_walletIndex));
}

/// The caution before the recovery phrase. Continue asks for approval, then
/// reads the phrase and hands its words to [onApproved].
class RecoveryPhraseCaution extends ConsumerStatefulWidget {
  const RecoveryPhraseCaution({super.key, required this.onCancel, required this.onApproved});

  final VoidCallback onCancel;
  final ValueChanged<List<String>> onApproved;

  @override
  ConsumerState<RecoveryPhraseCaution> createState() => _RecoveryPhraseCautionState();
}

class _RecoveryPhraseCautionState extends ConsumerState<RecoveryPhraseCaution> {
  bool _isBusy = false;
  String? _error;

  Future<void> _continue() async {
    final l10n = ref.read(l10nProvider);
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final refusal = await askForApproval(
      ref.read(userApprovalProvider),
      l10n,
      reason: l10n.settingsRecoveryConfirmAuthReason,
      declined: l10n.settingsRecoveryConfirmAuthRequired,
    );
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _isBusy = false;
        _error = refusal;
      });
      return;
    }

    String? phrase;
    try {
      phrase = await ref.read(settingsServiceProvider).getMnemonic(_walletIndex);
    } catch (e) {
      quantusPrint('Reading the recovery phrase failed: $e');
    }
    if (!mounted) return;
    if (phrase == null) {
      setState(() {
        _isBusy = false;
        _error = l10n.desktopRecoveryPhraseUnreadable;
      });
      return;
    }
    widget.onApproved(recoveryPhraseWords(phrase));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCaution(
          eyebrow: l10n.desktopRecoveryPhraseEyebrow,
          headline: l10n.createWalletCautionHeadline,
          lines: [l10n.createWalletCautionBullet1, l10n.createWalletCautionBullet2, l10n.createWalletCautionBullet3],
        ),
        const SizedBox(height: 10),
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
              key: SettingsSheet.continueKey,
              label: l10n.commonContinue,
              isLoading: _isBusy,
              onTap: _continue,
            ),
          ],
        ),
      ],
    );
  }
}

/// The recovery phrase's words once approved, masked until Show reveals them;
/// Hide masks them again. Copy puts them on the clipboard for a short time,
/// kept out of clipboard history.
class RecoveryPhraseWords extends ConsumerStatefulWidget {
  const RecoveryPhraseWords({super.key, required this.words, required this.onDone});

  final List<String> words;
  final VoidCallback onDone;

  @override
  ConsumerState<RecoveryPhraseWords> createState() => _RecoveryPhraseWordsState();
}

class _RecoveryPhraseWordsState extends ConsumerState<RecoveryPhraseWords> {
  bool _isRevealed = false;
  String? _error;

  void _toggleRevealed() {
    setState(() => _isRevealed = !_isRevealed);
    if (_isRevealed) _markPhraseSeen(ProviderScope.containerOf(context, listen: false));
  }

  Future<void> _copy(String text) async {
    // Taken before the copy, which the sheet may not outlive: Done, Escape
    // and Back still close it meanwhile.
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(sensitiveClipboardProvider).copy(text);
    _markPhraseSeen(container);
    if (mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.recoveryPhraseBodyInstructions, style: context.themeTextV3.body.copyWith(color: colors.textMuted)),
        const SizedBox(height: 20),
        RecoveryPhraseGrid(key: SettingsSheet.phraseGridKey, words: widget.words, isRevealed: _isRevealed),
        const SizedBox(height: 22),
        SettingsStepFooter(
          error: _error,
          leading: [
            ToolbarActionRow(
              edge: ToolbarActionEdge.leading,
              spacing: 6,
              children: [
                ToolbarAction.symbol(
                  key: SettingsSheet.hideKey,
                  symbol: _isRevealed ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  label: _isRevealed ? l10n.desktopRecoveryPhraseHide : l10n.desktopRecoveryPhraseShow,
                  onPressed: _toggleRevealed,
                ),
                CopyAction(
                  actionKey: SettingsSheet.copyKey,
                  text: widget.words.join(' '),
                  copyLabel: l10n.receiveCopy,
                  copiedLabel: l10n.desktopCopied,
                  copy: _copy,
                  onFailed: (e) {
                    quantusPrint('Copying the recovery phrase failed: $e');
                    // The sheet may have closed while the copy was made.
                    if (mounted) setState(() => _error = l10n.desktopRecoveryPhraseCopyFailed);
                  },
                ),
              ],
            ),
          ],
          buttons: [SheetButton(key: SettingsSheet.doneKey, label: l10n.commonDone, onTap: widget.onDone)],
        ),
      ],
    );
  }
}
