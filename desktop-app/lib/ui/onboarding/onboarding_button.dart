import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The button of an onboarding page. Every one is the same size whatever its
/// label says and whether or not it is busy, so a pair stays balanced and
/// the pages match.
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isSecondary = false,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSecondary;
  final bool isLoading;
  final bool isDisabled;

  static const Size _size = Size(200, 40);

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final labelColor = isDisabled
        ? colors.textMuted2
        : isSecondary
        ? colors.textContent
        : colors.textVoid;

    return SizedBox.fromSize(
      size: _size,
      child: QuantusButton.simple(
        label: label,
        onTap: onTap,
        isLoading: isLoading,
        isDisabled: isDisabled,
        variant: isSecondary ? ButtonVariant.staged : ButtonVariant.primary,
        width: _size.width,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: context.themeTextV3.bodyEmphasis.copyWith(height: 1, color: labelColor),
      ),
    );
  }
}
