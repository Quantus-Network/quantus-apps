import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// Any amount on screen. In discreet mode it reads as dots until hovered.
class AmountText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const AmountText(this.text, {super.key, required this.style, this.textAlign = TextAlign.start});

  @override
  ConsumerState<AmountText> createState() => _AmountTextState();
}

class _AmountTextState extends ConsumerState<AmountText> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(isBalanceHiddenProvider) && !_hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Text(hidden ? '••••' : widget.text, style: widget.style, textAlign: widget.textAlign),
    );
  }
}
