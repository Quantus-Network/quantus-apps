import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';

class BaseBackground extends StatelessWidget {
  final Widget child;

  const BaseBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(color: context.colors.background, child: child);
  }
}
