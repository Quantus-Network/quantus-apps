import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/recovery_phrase_input.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_button.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_text.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';

/// Imports the wallet of [mnemonic]. [onScanFailed] is asked whether to scan
/// the chain for its accounts again when that scan fails.
typedef ImportWallet =
    Future<void> Function(String mnemonic, {required Future<bool> Function(Object error) onScanFailed});

/// Restores a wallet from its recovery phrase: what to type on the left, the
/// phrase on the right.
class ImportWalletPage extends ConsumerStatefulWidget {
  const ImportWalletPage({super.key, required this.importWallet, required this.onImported, required this.onBack});

  final ImportWallet importWallet;
  final VoidCallback onImported;
  final VoidCallback onBack;

  /// The count of the words typed so far.
  static const wordCountKey = RecoveryPhraseInput.wordCountKey;

  @override
  ConsumerState<ImportWalletPage> createState() => _ImportWalletPageState();
}

class _ImportWalletPageState extends ConsumerState<ImportWalletPage> {
  static const double _textWidth = 360;
  static const double _fieldWidth = 400;
  static const double _gap = 56;

  final _controller = ObscuringTextEditingController();
  bool _isImporting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      await widget.importWallet(_controller.text, onScanFailed: _askToScanAgain);
      if (mounted) widget.onImported();
    } on InvalidRecoveryPhraseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      quantusPrint('Wallet import failed: $e');
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool> _askToScanAgain(Object error) async {
    if (!mounted) return false;
    final l10n = ref.read(l10nProvider);
    return showQuantusDialog(
      context,
      title: l10n.importWalletScanFailedTitle,
      body: l10n.importWalletScanFailedBody,
      actionLabel: l10n.importWalletScanRetry,
      cancelLabel: l10n.importWalletScanSkip,
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    // There is no going back from an import that is under way.
    final onBack = _isImporting ? null : widget.onBack;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): ?onBack},
      child: Focus(
        autofocus: true,
        child: OnboardingPage(
          contentWidth: _textWidth + _gap + 1 + _gap + _fieldWidth,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_back, size: 18),
            color: colors.textMuted,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.commonBack,
            onPressed: onBack,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _textWidth,
                child: _Words(l10n: l10n),
              ),
              const SizedBox(width: _gap),
              Container(width: 1, height: 300, color: colors.borderHairline),
              const SizedBox(width: _gap),
              SizedBox(
                width: _fieldWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CapsText(l10n.desktopImportPhraseLabel, style: _label(context, colors.textMuted2)),
                    const SizedBox(height: 12),
                    RecoveryPhraseInput(
                      controller: _controller,
                      height: 180,
                      canPaste: !_isImporting,
                      onChanged: () => setState(() {}),
                    ),
                    if (_error case final error?) ...[
                      const SizedBox(height: 12),
                      Text(error, style: text.caption.copyWith(color: colors.semanticEmber)),
                    ],
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OnboardingButton(
                        label: l10n.welcomeImportWallet,
                        onTap: _import,
                        isLoading: _isImporting,
                        isDisabled: _controller.text.trim().isEmpty,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small monospace capitals of the labels and tips.
TextStyle _label(BuildContext context, Color color) => RecoveryPhraseInput.labelStyle(context, color);

/// The left side: what this page is for, and how to type the phrase.
class _Words extends StatelessWidget {
  const _Words({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    Widget tip(String tip) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ExcludeSemantics(child: Text('→', style: _label(context, colors.accentFlare))),
          const SizedBox(width: 10),
          Expanded(child: CapsText(tip, style: _label(context, colors.textMuted))),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CapsText(
          l10n.importWalletAppBarTitle,
          style: context.themeTextV3.dataAddress.copyWith(color: colors.accentFlare, letterSpacing: 2.4, height: 1),
        ),
        const SizedBox(height: 18),
        OnboardingHeadline(l10n.desktopImportHeadline),
        const SizedBox(height: 14),
        OnboardingLede(l10n.importWalletDescription),
        const SizedBox(height: 28),
        tip(l10n.desktopImportTipWordCount),
        tip(l10n.desktopImportTipSpaces),
        tip(l10n.desktopImportTipPaste),
      ],
    );
  }
}
