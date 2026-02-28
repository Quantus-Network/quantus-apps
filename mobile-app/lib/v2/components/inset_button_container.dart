import 'package:flutter/material.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:quantus_sdk/quantus_sdk.dart';

class InsetButtonContainer extends StatelessWidget {
  final Widget child;

  final EdgeInsetsGeometry? padding;
  final double? width;
  final Color? backgroundColor;
  final BoxBorder? border;

  const InsetButtonContainer({
    super.key,
    required this.child,
    this.width,
    this.padding,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: inset.BoxDecoration(
        borderRadius: BorderRadius.circular(14.0),
        color: backgroundColor,
        boxShadow: [
          inset.BoxShadow(
            color: Colors.black.useOpacity(0.3),
            blurRadius: 56,
            spreadRadius: -38,
            offset: const Offset(12, 12),
            inset: true,
          ),
          inset.BoxShadow(
            color: Colors.white.useOpacity(0.3),
            blurRadius: 56,
            spreadRadius: -38,
            offset: const Offset(-12, -12),
            inset: true,
          ),
        ],
        border: border,
      ),
      child: child,
    );
  }
}
