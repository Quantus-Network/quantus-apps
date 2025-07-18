import 'package:flutter/material.dart';

class MnemonicGrid extends StatelessWidget {
  final List<String> words;

  const MnemonicGrid({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 9),
      decoration: ShapeDecoration(
        color: Colors.black.withOpacity(
          0.7,
        ), // Assuming 'useOpacity' is a custom extension; using standard 'withOpacity'
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 9.0,
        childAspectRatio: (105 / 38),
        children: List.generate(words.length, (index) {
          return _buildMnemonicWord(index + 1, words[index]);
        }),
      ),
    );
  }

  Widget _buildMnemonicWord(int index, String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: Colors.white.withOpacity(0.15),
          ), // Assuming 'useOpacity' is a custom extension; using standard 'withOpacity'
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        '$index.$word',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Fira Code',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
