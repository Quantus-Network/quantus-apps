import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/mnemonic_grid.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class ShowSecretPhraseScreen extends ConsumerStatefulWidget {
  const ShowSecretPhraseScreen({super.key});

  @override
  ConsumerState<ShowSecretPhraseScreen> createState() => _ShowSecretPhraseScreenState();
}

class _ShowSecretPhraseScreenState extends ConsumerState<ShowSecretPhraseScreen> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    // Locking clears the mnemonic while the LockOverlay covers this route;
    // re-hide so unlocking does not land on an exposed phrase.
    ref.listen(walletControllerProvider.select((s) => s.mnemonic), (_, mnemonic) {
      if (mnemonic == null && _isRevealed) setState(() => _isRevealed = false);
    });
    final mnemonic = ref.watch(walletControllerProvider.select((s) => s.mnemonic));
    final words = mnemonic?.split(' ') ?? const <String>[];

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Secret phrase'),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Anyone with this phrase controls your funds. Never share it and never enter it on a device that '
            'goes online.',
            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: GestureDetector(
                onTap: () => setState(() => _isRevealed = !_isRevealed),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        MnemonicGrid(words: words, isRevealed: _isRevealed),
                        if (!_isRevealed)
                          _tapHint(Icons.visibility_outlined, 'Tap to reveal', colors.textPrimary, text),
                      ],
                    ),
                    if (_isRevealed) ...[
                      const SizedBox(height: 16),
                      _tapHint(Icons.visibility_off_outlined, 'Tap to hide', colors.textSecondary, text),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Done', onTap: () => Navigator.pop(context)),
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
}
