import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';

/// Imports the wallet of [mnemonic]. [onScanFailed] is asked whether to scan
/// the chain for its accounts again when that scan fails.
typedef ImportWallet =
    Future<void> Function(String mnemonic, {required Future<bool> Function(Object error) onScanFailed});

/// Restores a wallet from its recovery phrase.
class ImportWalletPage extends ConsumerStatefulWidget {
  const ImportWalletPage({super.key, required this.importWallet, required this.onImported, required this.onBack});

  final ImportWallet importWallet;
  final VoidCallback onImported;
  final VoidCallback onBack;

  @override
  ConsumerState<ImportWalletPage> createState() => _ImportWalletPageState();
}

class _ImportWalletPageState extends ConsumerState<ImportWalletPage> {
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
          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_back, size: 18),
            color: colors.textMuted,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.commonBack,
            onPressed: onBack,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.importWalletAppBarTitle, style: text.titleHero.copyWith(color: colors.textContent)),
              const SizedBox(height: 8),
              Text(l10n.importWalletDescription, style: text.body.copyWith(color: colors.textMuted)),
              const SizedBox(height: 24),
              QuantusSeedPhraseField(
                controller: _controller,
                hint: l10n.importWalletHint,
                onChanged: (_) => setState(() {}),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                Text(error, style: text.caption.copyWith(color: colors.semanticEmber)),
              ],
              const SizedBox(height: 24),
              QuantusButton.simple(
                label: l10n.importWalletButton,
                onTap: _import,
                isLoading: _isImporting,
                isDisabled: _controller.text.trim().isEmpty,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
