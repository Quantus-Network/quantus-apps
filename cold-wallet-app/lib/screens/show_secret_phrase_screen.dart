import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Shows [phrase], which the wallet released after confirming it is the user
/// asking. It is closed again whenever that confirmation stops holding.
class ShowSecretPhraseScreen extends ConsumerStatefulWidget {
  final String phrase;

  const ShowSecretPhraseScreen({super.key, required this.phrase});

  @override
  ConsumerState<ShowSecretPhraseScreen> createState() => _ShowSecretPhraseScreenState();
}

class _ShowSecretPhraseScreenState extends ConsumerState<ShowSecretPhraseScreen> {
  bool _isRevealed = false;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _closeIfSealed);
  }

  /// A sealed wallet has no lock to cover the phrase when the app leaves the
  /// foreground, so the screen goes instead and the next look needs Face ID.
  void _closeIfSealed() {
    if (ref.read(walletControllerProvider.notifier).sealed) Navigator.pop(context);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    // The LockOverlay covers this route while the wallet is locked; re-hide so
    // unlocking does not land on an exposed phrase.
    ref.listen(walletControllerProvider.select((s) => s.status), (_, status) {
      if (status != WalletStatus.unlocked && _isRevealed) setState(() => _isRevealed = false);
    });
    final words = widget.phrase.split(' ');

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
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: context.radiusV3.mdBorder,
                  border: Border.all(color: colors.borderHairline),
                ),
                child: MnemonicRevealGrid(
                  words: words,
                  isRevealed: _isRevealed,
                  revealHint: 'Tap to reveal',
                  hideHint: 'Tap to hide',
                  onToggle: () => setState(() => _isRevealed = !_isRevealed),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Done', padding: coldButtonPadding, onTap: () => Navigator.pop(context)),
      ),
    );
  }
}
