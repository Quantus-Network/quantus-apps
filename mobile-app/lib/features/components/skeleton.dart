import 'package:flutter/material.dart';
import '../styles/app_colors_theme.dart';

const _defaultSkeletonBaseColor = Color(0xFF3D3C44);
const _defaultSkeletonHighlightColor = Color(0xFF5A5A5A);

/// A skeleton widget with shimmer animation for loading states
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Duration duration;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// Creates a circular skeleton (useful for avatars)
  const Skeleton.circular({
    super.key,
    required double size,
    this.duration = const Duration(milliseconds: 1500),
  }) : width = size,
       height = size,
       borderRadius = null;

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
    final themeColors = Theme.of(context).extension<AppColorsTheme>();
    final baseColor = themeColors?.skeletonBase ?? _defaultSkeletonBaseColor;
    final highlightColor = themeColors?.skeletonHighlight ?? _defaultSkeletonHighlightColor;
    
    final borderRadius =
        widget.borderRadius ??
        (widget.width == widget.height ? BorderRadius.circular(widget.width ?? 0) : BorderRadius.circular(4));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlideGradientTransform(_animation.value),
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
