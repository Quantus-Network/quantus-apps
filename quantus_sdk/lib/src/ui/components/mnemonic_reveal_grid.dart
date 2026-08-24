import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Mnemonic grid with a tap-to-reveal overlay.
///
/// Blurs [MnemonicGrid] until [isRevealed] is true. Callers own reveal state so
/// they can reset it (e.g. on lock) or react to first reveal.
class MnemonicRevealGrid extends StatelessWidget {
  final List<String> words;
  final bool isRevealed;
  final String revealHint;
  final String hideHint;
  final VoidCallback onToggle;

  /// Optional key on the hide hint, used by host-app e2e selectors.
  final Key? hideHintKey;

  const MnemonicRevealGrid({
    super.key,
    required this.words,
    required this.isRevealed,
    required this.revealHint,
    required this.hideHint,
    required this.onToggle,
    this.hideHintKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              MnemonicGrid(words: words, isRevealed: isRevealed),
              if (!isRevealed)
                _MnemonicRevealHint(icon: Icons.visibility_outlined, label: revealHint, color: colors.textContent),
            ],
          ),
          if (isRevealed) ...[
            const SizedBox(height: 16),
            _MnemonicRevealHint(
              key: hideHintKey,
              icon: Icons.visibility_off_outlined,
              label: hideHint,
              color: colors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _MnemonicRevealHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MnemonicRevealHint({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: context.themeTextV3.body.copyWith(color: color)),
      ],
    );
  }
}
