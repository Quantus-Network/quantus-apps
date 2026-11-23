import 'package:flutter/widgets.dart';

/// [text] drawn in capitals, which is a look: a screen reader gets the words
/// as they are written.
class CapsText extends StatelessWidget {
  const CapsText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Text(text.toUpperCase(), style: style),
    );
  }
}
