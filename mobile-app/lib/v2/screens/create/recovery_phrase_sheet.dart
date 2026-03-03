import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class RecoveryPhraseSheet extends StatelessWidget {
  final List<String> words;
  final bool isLoading;
  final String? error;
  final String mnemonic;

  const RecoveryPhraseSheet({
    super.key,
    required this.words,
    required this.isLoading,
    required this.error,
    required this.mnemonic,
  });

  @override
  Widget build(BuildContext context) {
    return BottomSheetContainer(
      title: 'Backup Your Wallet',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Write down your 24-word recovery phrase and store it somewhere safe. This is the ONLY way to recover your wallet.',
            style: context.themeText.smallParagraph,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MnemonicGrid(words: words, isRevealed: true),
          const SizedBox(height: 16),
          Button.simple(
            padding: const EdgeInsets.all(0),
            label: 'Copy to clipboard',
            icon: Icon(Icons.copy, color: context.colors.textPrimary, size: 14),
            onTap: () => context.copyTextWithToaster(mnemonic, message: 'Recovery phrase copied to clipboard'),
            variant: ButtonVariant.transparent,
          ),
        ],
      ),
    );
  }
}

void showRecoveryPhraseSheet(BuildContext context, List<String> words, bool isLoading, String? error, String mnemonic) {
  BottomSheetContainer.show(
    context,
    builder: (_) => RecoveryPhraseSheet(words: words, isLoading: isLoading, error: error, mnemonic: mnemonic),
  );
}
