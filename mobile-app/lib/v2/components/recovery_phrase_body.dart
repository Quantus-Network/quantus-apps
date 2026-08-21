import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';

class RecoveryPhraseBody extends ConsumerStatefulWidget {
  final String appBarTitle;
  final List<String> words;
  final String primaryButtonLabel;
  final VoidCallback onPrimary;
  final bool isGridLoading;
  final bool isPrimaryButtonDisabled;
  final bool isPrimaryButtonLoading;

  /// Called once, the first time the user reveals or copies the phrase.
  final VoidCallback? onPhraseExposed;

  const RecoveryPhraseBody({
    super.key,
    required this.appBarTitle,
    required this.words,
    required this.primaryButtonLabel,
    required this.onPrimary,
    this.isGridLoading = false,
    this.isPrimaryButtonDisabled = false,
    this.isPrimaryButtonLoading = false,
    this.onPhraseExposed,
  });

  @override
  ConsumerState<RecoveryPhraseBody> createState() => _RecoveryPhraseBodyState();
}

class _RecoveryPhraseBodyState extends ConsumerState<RecoveryPhraseBody> {
  bool _isRevealed = false;
  bool _exposed = false;

  void _markExposed() {
    if (_exposed) return;
    _exposed = true;
    widget.onPhraseExposed?.call();
  }

  void _toggleRevealed() {
    setState(() => _isRevealed = !_isRevealed);
    if (_isRevealed) _markExposed();
  }

  void _copyToClipboard() {
    final l10n = ref.read(l10nProvider);
    context.copySensitiveTextWithToaster(widget.words.join(' '), message: l10n.recoveryPhraseBodyCopiedMessage);
    _markExposed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: V2AppBar(title: widget.appBarTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.recoveryPhraseBodyInstructions, style: text.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: 24),
          Expanded(
            child: widget.isGridLoading
                ? const Center(child: Loader(size: 24))
                : SingleChildScrollView(child: _grid(l10n, colors, text)),
          ),
        ],
      ),
      bottomContent: _bottomBar(l10n),
    );
  }

  Widget _grid(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    return GestureDetector(
      key: const Key(E2EKeys.recoveryPhraseRevealArea),
      onTap: _toggleRevealed,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              MnemonicGrid(words: widget.words, isRevealed: _isRevealed),
              if (!_isRevealed)
                _tapHint(Icons.visibility_outlined, l10n.recoveryPhraseBodyTapToReveal, colors.textContent, text),
            ],
          ),
          if (_isRevealed) ...[
            const SizedBox(height: 16),
            _tapHint(
              Icons.visibility_off_outlined,
              l10n.recoveryPhraseBodyTapToHide,
              colors.textMuted,
              text,
              key: const Key(E2EKeys.recoveryPhraseRevealed),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tapHint(IconData icon, String label, Color color, AppTextThemeV3 text, {Key? key}) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: text.body.copyWith(color: color)),
      ],
    );
  }

  Widget _bottomBar(AppLocalizations l10n) {
    return ScaffoldBaseBottomContent(
      child: Row(
        children: [
          Expanded(
            child: QuantusButton.simple(
              label: l10n.recoveryPhraseBodyCopy,
              onTap: _copyToClipboard,
              variant: ButtonVariant.staged,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: QuantusButton.simple(
              label: widget.primaryButtonLabel,
              isDisabled: widget.isPrimaryButtonDisabled,
              isLoading: widget.isPrimaryButtonLoading,
              onTap: widget.onPrimary,
              variant: ButtonVariant.primary,
            ),
          ),
        ],
      ),
    );
  }
}
