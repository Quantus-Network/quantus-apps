import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/recovery_phrase_input.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/import_wallet_page.dart' show ImportWallet;
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';

/// Adds a wallet from its recovery phrase, the only thing it asks for: the
/// wallet is named afterwards, in the sidebar. It closes once the wallet is
/// in, and cannot be closed while it is going in.
class ImportWalletSheet extends ConsumerStatefulWidget {
  const ImportWalletSheet({super.key, required this.importWallet});

  final ImportWallet importWallet;

  @override
  ConsumerState<ImportWalletSheet> createState() => _ImportWalletSheetState();
}

class _ImportWalletSheetState extends ConsumerState<ImportWalletSheet> {
  static const double _fieldHeight = 148;

  final _controller = ObscuringTextEditingController();
  bool _isImporting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final l10n = ref.read(l10nProvider);
    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      await widget.importWallet(_controller.text, onScanFailed: _askToScanAgain);
    } on InvalidRecoveryPhraseException catch (e) {
      _showError(e.message);
      return;
    } catch (e) {
      quantusPrint('Importing a wallet failed: $e');
      _showError(l10n.desktopImportFailed);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isImporting = false;
      _error = message;
    });
  }

  Future<bool> _askToScanAgain(Object error) async {
    if (!mounted) return false;
    return askToScanImportAgain(context, ref.read(l10nProvider));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final error = _error;

    return PopScope(
      canPop: !_isImporting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellSheetHeader(title: l10n.importWalletAppBarTitle),
          const SizedBox(height: 20),
          Text(l10n.importWalletDescription, style: text.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: 16),
          RecoveryPhraseInput(
            controller: _controller,
            height: _fieldHeight,
            autofocus: true,
            canPaste: !_isImporting,
            onChanged: () => setState(() {}),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(error, style: text.caption.copyWith(color: colors.semanticEmber)),
            ),
          ],
          if (_isImporting) ...[const SizedBox(height: 14), _FindingLine(label: l10n.desktopImportFinding)],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 10,
            children: [
              if (!_isImporting)
                SheetButton(
                  label: l10n.commonCancel,
                  kind: SheetButtonKind.secondary,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              SheetButton(
                label: l10n.welcomeImportWallet,
                onTap: _import,
                isDisabled: _isImporting || _controller.text.trim().isEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What is happening while the wallet goes in, with the terminal's spinner
/// unless the system asks for less motion.
class _FindingLine extends StatelessWidget {
  const _FindingLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = context.themeTextV3.dataAddress.copyWith(color: context.colorsV3.textMuted);

    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Row(
        spacing: 8,
        children: [
          if (!MediaQuery.disableAnimationsOf(context)) TerminalSpinner(style: style),
          Flexible(child: Text(label, style: style)),
        ],
      ),
    );
  }
}
