import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A recovery phrase's words in four numbered columns, read down each
/// column, as they are written out on paper.
///
/// Unrevealed, every word shows the same [maskedWord], so no word's length
/// shows, and a screen reader is given none of them.
class RecoveryPhraseGrid extends StatelessWidget {
  const RecoveryPhraseGrid({super.key, required this.words, required this.isRevealed});

  final List<String> words;
  final bool isRevealed;

  static const maskedWord = '••••••';

  static const int _columns = 4;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final rows = (words.length / _columns).ceil();

    return ExcludeSemantics(
      excluding: !isRevealed,
      child: Column(
        children: [
          for (var row = 0; row < rows; row++)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
              child: Row(
                children: [
                  for (var column = 0; column < _columns; column++) ...[
                    if (column > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: switch (column * rows + row) {
                        final index when index < words.length => _Word(
                          number: index + 1,
                          word: isRevealed ? words[index] : maskedWord,
                          isRevealed: isRevealed,
                        ),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.number, required this.word, required this.isRevealed});

  final int number;
  final String word;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.bgSurface2,
        borderRadius: context.radiusV3.smBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: text.dataAddress.copyWith(height: 1, color: colors.textMuted2),
            ),
          ),
          Expanded(
            child: Text(
              word,
              overflow: TextOverflow.ellipsis,
              style: text.dataAddressLarge.copyWith(
                height: 1,
                color: isRevealed ? colors.textWhite : colors.textMuted2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
