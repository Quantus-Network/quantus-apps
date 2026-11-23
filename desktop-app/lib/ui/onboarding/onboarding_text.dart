import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The large headline of an onboarding page after Welcome.
class OnboardingHeadline extends StatelessWidget {
  const OnboardingHeadline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.themeTextV3.titleHero.copyWith(
        fontSize: 44,
        height: 1.05,
        letterSpacing: -1.1,
        color: context.colorsV3.textWhite,
      ),
    );
  }
}

/// The muted sentence under an [OnboardingHeadline].
class OnboardingLede extends StatelessWidget {
  const OnboardingLede(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.themeTextV3.bodyLarge.copyWith(
        height: 1.45,
        letterSpacing: 0.2,
        color: context.colorsV3.textContent.useOpacity(0.6),
      ),
    );
  }
}
