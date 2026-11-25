import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// What the person chose on [showMissingPhraseDialog].
enum MissingPhraseChoice { tryAgain, quit, removeWallet }

/// Says the first wallet's recovery phrase could not be read at start, and
/// asks what to do. Only a button closes it: the wallet is not usable, and
/// removing it must be chosen. Null when the dialog went without an answer,
/// as when the window closes.
Future<MissingPhraseChoice?> showMissingPhraseDialog(BuildContext context, AppLocalizations l10n) {
  return showGeneralDialog<MissingPhraseChoice>(
    context: context,
    barrierDismissible: false,
    barrierColor: context.colorsV3.bgVoid.useOpacity(0.55),
    transitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) => Center(child: MissingPhraseDialog(l10n: l10n)),
  );
}

/// The dialog of [showMissingPhraseDialog]: Remove Wallet… apart on the left,
/// Quit and Try Again on the right.
class MissingPhraseDialog extends StatelessWidget {
  const MissingPhraseDialog({super.key, required this.l10n});

  final AppLocalizations l10n;

  static const double width = 540;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    void choose(MissingPhraseChoice choice) => Navigator.of(context).pop(choice);

    // Escape and the system's back do nothing: only a choice closes it.
    return PopScope(
      canPop: false,
      child: Actions(
        actions: {DismissIntent: DoNothingAction(consumesKey: true)},
        child: Focus(
          autofocus: true,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: width,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: context.radiusV3.lgBorder,
                border: Border.all(color: colors.borderEmphasis),
                boxShadow: [
                  BoxShadow(color: colors.bgVoid.useOpacity(0.7), blurRadius: 48, offset: const Offset(0, 18)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.walletInitErrorTitle, style: text.titleScreen.copyWith(color: colors.textContent)),
                  const SizedBox(height: 6),
                  Text(l10n.walletInitErrorMessage, style: text.body.copyWith(height: 1.5, color: colors.textMuted)),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      SheetButton(
                        label: l10n.desktopWalletInitErrorRemoveWallet,
                        kind: SheetButtonKind.destructive,
                        onTap: () => choose(MissingPhraseChoice.removeWallet),
                      ),
                      const Spacer(),
                      SheetButton(
                        label: l10n.desktopSystemQuit,
                        kind: SheetButtonKind.secondary,
                        onTap: () => choose(MissingPhraseChoice.quit),
                      ),
                      const SizedBox(width: 10),
                      SheetButton(label: l10n.commonTryAgain, onTap: () => choose(MissingPhraseChoice.tryAgain)),
                    ],
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
