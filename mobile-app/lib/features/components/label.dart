import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class Label extends StatelessWidget {
  final String data;

  const Label(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(data, style: context.themeText.tag?.copyWith(color: context.themeColors.inputLabel));
  }
}
