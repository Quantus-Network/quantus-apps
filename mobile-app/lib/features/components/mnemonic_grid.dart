import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/v2/components/liquid_glass_base.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class MnemonicGrid extends StatelessWidget {
  final List<String> words;
  final bool isRevealed;

  const MnemonicGrid({super.key, required this.words, this.isRevealed = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the available width for each item
        // constraints.maxWidth is the total width of the GridView
        // 2 * crossAxisSpacing (for the gaps between 3 items)
        // Adjust for any padding within the _buildMnemonicWord container
        final double availableWidth = constraints.maxWidth - (2 * 9.0); // 2 gaps of 9.0
        final double itemWidth = (availableWidth / 3); // 3 items per row

        // You might need to adjust this value slightly based on padding/margins
        // and font rendering.
        final double desiredCellHeight = context.isTablet ? 61 : 36.0;

        // Calculate the aspect ratio
        final double childAspectRatio = itemWidth / desiredCellHeight;

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10.0,
          crossAxisSpacing: 9.0,
          childAspectRatio: childAspectRatio,
          children: List.generate(words.length, (index) {
            return _buildMnemonicWord(index + 1, words[index], isRevealed, context);
          }),
        );
      },
    );
  }

  Widget _buildMnemonicWord(int index, String word, bool isRevealed, BuildContext context) {
    final padding = const EdgeInsets.symmetric(horizontal: 12);
    final double blur = isRevealed ? 0 : 5;
    final effectiveWord = isRevealed ? word : 'x' * word.length;

    return LiquidGlassBase.rounded(
      glassColor: context.colors.surfaceGlass,
      child: SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Text(
                '$index',
                textAlign: TextAlign.left,
                style: context.themeText.detail?.copyWith(color: context.colors.textPrimary.useOpacity(0.5)),
              ),
              const SizedBox(width: 8),
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Text(effectiveWord, textAlign: TextAlign.left, style: context.themeText.detail),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
