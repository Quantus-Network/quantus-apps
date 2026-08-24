import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

class ShowSecretPhraseScreen extends ConsumerStatefulWidget {
  const ShowSecretPhraseScreen({super.key});

  @override
  ConsumerState<ShowSecretPhraseScreen> createState() => _ShowSecretPhraseScreenState();
}

class _ShowSecretPhraseScreenState extends ConsumerState<ShowSecretPhraseScreen> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

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
            style: text.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: MnemonicRevealGrid(
                words: words,
                isRevealed: _isRevealed,
                revealHint: 'Tap to reveal',
                hideHint: 'Tap to hide',
                onToggle: () => setState(() => _isRevealed = !_isRevealed),
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
}
