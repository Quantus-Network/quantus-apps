import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class MnemonicGrid extends StatelessWidget {
  final List<String> words;

  const MnemonicGrid({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12.5),
      decoration: ShapeDecoration(
        color: Colors.black.useOpacity(0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the available width for each item
          // constraints.maxWidth is the total width of the GridView
          // 2 * crossAxisSpacing (for the gaps between 3 items)
          // Adjust for any padding within the _buildMnemonicWord container
          final double availableWidth = constraints.maxWidth - (2 * 9.0); // 2 gaps of 9.0
          final double itemWidth = (availableWidth / 3); // 3 items per row

          // You might need to adjust this value slightly based on padding/margins
          // and font rendering.
          final double desiredCellHeight = context.isTablet ? 56 : 31.0;

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
              return _buildMnemonicWord(index + 1, words[index], context);
            }),
          );
        },
      ),
    );
  }

  Widget _buildMnemonicWord(int index, String word, BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: Colors.white.useOpacity(0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      alignment: Alignment.center,
      child: Text('$index.$word', textAlign: TextAlign.center, style: context.themeText.detail),
    );
  }
}
