import 'package:flutter/material.dart';
import 'dart:ui';

class GlassButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool filled;
  final double height;

  const GlassButton({
    super.key,
    this.onTap,
    required this.child,
    required this.height,
    this.radius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final outerBorderColor = filled
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.32)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.44);
    final innerBorderColor = filled
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.18)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.12);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    color: filled ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : Colors.transparent,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(color: outerBorderColor, width: 0.889),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius - 1),
                    border: Border.all(color: innerBorderColor, width: 0.6),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.16),
                    ],
                    stops: const [0.0, 0.22, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: Center(child: child),
            ),
          ],
        ),
      ),
    );
  }
}
