import 'package:flutter/material.dart';

/// Masks seed phrase input while keeping the underlying [text] intact.
class SeedPhraseController extends TextEditingController {
  bool obscure = true;

  static String _mask(String text) => text.replaceAllMapped(RegExp(r'\S'), (_) => '*');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final text = value.text;
    final display = obscure ? _mask(text) : text;

    if (!withComposing || !value.composing.isValid) {
      return TextSpan(style: style, text: display);
    }

    final composingStart = value.composing.start;
    final composingEnd = value.composing.end;

    return TextSpan(
      style: style,
      children: [
        TextSpan(text: display.substring(0, composingStart)),
        TextSpan(
          style: style?.copyWith(decoration: TextDecoration.underline, decorationColor: style.color),
          text: display.substring(composingStart, composingEnd),
        ),
        TextSpan(text: display.substring(composingEnd)),
      ],
    );
  }
}
