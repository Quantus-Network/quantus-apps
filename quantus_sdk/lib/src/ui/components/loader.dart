import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class Loader extends StatelessWidget {
  final Color? color;
  final double? size;

  const Loader({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? (context.isTablet ? 24 : 16);

    return SizedBox(
      height: effectiveSize,
      width: effectiveSize,
      child: CircularProgressIndicator(strokeWidth: 2, color: color ?? context.colorsV3.textMuted),
    );
  }
}
