import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class RecoveryPhraseBody extends ConsumerWidget {
  final String appBarTitle;
  final List<String> words;
  final String primaryButtonLabel;
  final VoidCallback onPrimary;
  final bool isGridLoading;
  final bool isPrimaryButtonDisabled;
  final bool isPrimaryButtonLoading;

  const RecoveryPhraseBody({
    super.key,
    required this.appBarTitle,
    required this.words,
    required this.primaryButtonLabel,
    required this.onPrimary,
    this.isGridLoading = false,
    this.isPrimaryButtonDisabled = false,
    this.isPrimaryButtonLoading = false,
  });

  void _copyToClipboard(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(l10nProvider);
    context.copyTextWithToaster(words.join(' '), message: l10n.recoveryPhraseBodyCopiedMessage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: V2AppBar(title: appBarTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.recoveryPhraseBodyInstructions, style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: 24),
          Expanded(
            child: isGridLoading
                ? const Center(child: Loader(size: 24))
                : SingleChildScrollView(child: MnemonicGrid(words: words, isRevealed: true)),
          ),
        ],
      ),
      bottomContent: _bottomBar(context, ref, colors),
    );
  }

  Widget _bottomBar(BuildContext context, WidgetRef ref, AppColorsV2 colors) {
    final l10n = ref.watch(l10nProvider);
    final padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    return ScaffoldBaseBottomContent(
      child: Row(
        children: [
          Expanded(
            child: QuantusButton.simple(
              label: l10n.recoveryPhraseBodyCopy,
              icon: Icon(Icons.copy, color: colors.textPrimary, size: 14),
              iconPlacement: IconPlacement.leading,
              onTap: () => _copyToClipboard(context, ref),
              variant: ButtonVariant.secondary,
              padding: padding,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: QuantusButton.simple(
              label: primaryButtonLabel,
              isDisabled: isPrimaryButtonDisabled,
              isLoading: isPrimaryButtonLoading,
              onTap: onPrimary,
              variant: ButtonVariant.primary,
              padding: padding,
            ),
          ),
        ],
      ),
    );
  }
}
