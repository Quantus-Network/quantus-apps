import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shimmering loading bone. Compose rows and screens from sized instances.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Duration duration;

  static const defaultDuration = Duration(milliseconds: 1200);

  const Skeleton({super.key, this.width, this.height = 16, this.borderRadius, this.duration = defaultDuration});

  /// Circular bone for avatars and icon placeholders.
  Skeleton.circular({super.key, required double size, this.duration = defaultDuration})
    : width = size,
      height = size,
      borderRadius = BorderRadius.circular(size);

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();

    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final borderRadius = widget.borderRadius ?? context.radiusV3.xsBorder;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(borderRadius: borderRadius, color: colors.bgSurface),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  colors.bgVoid.useOpacity(0.2),
                  colors.textMuted2.useOpacity(0.2),
                  colors.bgVoid.useOpacity(0.2),
                ],
                stops: const [0.0, 0.5, 1.0],
                transform: _SlideGradientTransform(_animation.value),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
