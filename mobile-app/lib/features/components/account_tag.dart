import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class AccountTag extends StatelessWidget {
  final String text;
  final Color color;
  final double? width;

  const AccountTag({super.key, required this.text, required this.color, this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: ShapeDecoration(
            color: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: context.themeText.tiny?.copyWith(color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
