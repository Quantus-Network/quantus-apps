import 'package:flutter/material.dart';

/// Two equal columns when there is room, one column below [twoColumnMinWidth].
class CardGrid extends StatelessWidget {
  static const double twoColumnMinWidth = 840;
  static const double gap = 24;

  final List<Widget> children;

  const CardGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < twoColumnMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: gap), children[i]],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}
