import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class LoadingTextAnimation extends StatefulWidget {
  const LoadingTextAnimation({super.key});

  @override
  State<LoadingTextAnimation> createState() => _LoadingTextAnimationState();
}

class _LoadingTextAnimationState extends State<LoadingTextAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const text = 'Loading...';
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(text.length, (index) {
            final delay = index * 0.08;
            var value = (_controller.value - delay) % 1.0;
            if (value < 0) value += 1.0;
            
            final normalizedValue = (value * 2).clamp(0.0, 1.0);
            final opacity = Curves.easeInOut.transform(
              normalizedValue > 1.0 ? 2.0 - normalizedValue : normalizedValue,
            );
            
            return Opacity(
              opacity: 0.3 + (0.7 * opacity),
              child: Text(
                text[index],
                style: context.themeText.mediumTitle,
              ),
            );
          }),
        );
      },
    );
  }
}