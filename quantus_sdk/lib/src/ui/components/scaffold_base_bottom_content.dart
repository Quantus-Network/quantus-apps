import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class ScaffoldBaseBottomContent extends StatelessWidget {
  final Widget child;

  const ScaffoldBaseBottomContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final padding = const EdgeInsets.all(24);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colorsV3.borderHairline, width: 1)),
      ),
      child: child,
    );
  }
}
