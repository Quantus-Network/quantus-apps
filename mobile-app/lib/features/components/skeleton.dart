import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

/// A skeleton widget with shimmer animation for loading states
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Duration duration;

  static const defaultDuration = Duration(milliseconds: 1200);

  const Skeleton({super.key, this.width, this.height = 16, this.borderRadius, this.duration = defaultDuration});

  /// Creates a circular skeleton (useful for avatars)
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
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(4);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(borderRadius: borderRadius, color: context.colors.skeletonBase),
          child: Opacity(
            opacity: 0.2,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    context.colors.skeletonHighlightA,
                    context.colors.skeletonHighlightB,
                    context.colors.skeletonHighlightA,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  transform: _SlideGradientTransform(_animation.value),
                ),
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

class TxItemSkeleton extends StatelessWidget {
  const TxItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final double txItemHeight = 32.0;
    final double txItemDetailHeight = 12.0;

    return Row(
      children: [
        Skeleton(width: txItemHeight, height: txItemHeight),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 64, height: txItemDetailHeight),
            const SizedBox(height: 6),
            Skeleton(width: 52, height: txItemDetailHeight),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Skeleton(width: 100, height: txItemDetailHeight),
            const SizedBox(height: 6),
            Skeleton(width: 88, height: txItemDetailHeight),
          ],
        ),
      ],
    );
  }
}
