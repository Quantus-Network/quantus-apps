import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class ScaffoldBaseBottomContent extends StatelessWidget {
  final Widget child;

  const ScaffoldBaseBottomContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final padding = const EdgeInsets.all(24);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.surfaceDeep, width: 1)),
      ),
      child: child,
    );
  }
}
