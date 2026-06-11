import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
    context.copyTextWithToaster(widget.words.join(' '), message: l10n.recoveryPhraseBodyCopiedMessage);
    _markExposed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: V2AppBar(title: widget.appBarTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.recoveryPhraseBodyInstructions, style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: 24),
          Expanded(
            child: widget.isGridLoading
                ? const Center(child: Loader(size: 24))
                : SingleChildScrollView(child: _grid(l10n, colors, text)),
          ),
        ],
      ),
      bottomContent: _bottomBar(l10n, colors),
    );
  }

  Widget _grid(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: _toggleRevealed,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              MnemonicGrid(words: widget.words, isRevealed: _isRevealed),
              if (!_isRevealed)
                _tapHint(Icons.visibility_outlined, l10n.recoveryPhraseBodyTapToReveal, colors.textPrimary, text),
            ],
          ),
          if (_isRevealed) ...[
            const SizedBox(height: 16),
            _tapHint(Icons.visibility_off_outlined, l10n.recoveryPhraseBodyTapToHide, colors.textSecondary, text),
          ],
        ],
      ),
    );
  }

  Widget _tapHint(IconData icon, String label, Color color, AppTextTheme text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: text.smallParagraph?.copyWith(color: color)),
      ],
    );
  }

  Widget _bottomBar(AppLocalizations l10n, AppColorsV2 colors) {
    const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    return ScaffoldBaseBottomContent(
      child: Row(
        children: [
          Expanded(
            child: QuantusButton.simple(
              label: l10n.recoveryPhraseBodyCopy,
              icon: Icon(Icons.copy, color: colors.textPrimary, size: 14),
              iconPlacement: IconPlacement.leading,
              onTap: _copyToClipboard,
              variant: ButtonVariant.secondary,
              padding: padding,
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
              padding: padding,
            ),
          ),
        ],
      ),
    );
  }
}
