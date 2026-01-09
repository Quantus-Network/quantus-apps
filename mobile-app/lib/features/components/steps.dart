import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';

class StepsIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final double lineHeight = 2;
  final double iconHeight = 6.56;

  const StepsIndicator({super.key, required this.currentStep, required this.totalSteps})
    : assert(currentStep >= 1 && currentStep <= totalSteps);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: iconHeight,
          child: Row(
            children: List.generate(totalSteps, (index) {
              return Expanded(
                child: Row(
                  children: [if (index < totalSteps) _buildStepLine(context, index), _buildStepPoint(context, index)],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStepPoint(BuildContext context, int index) {
    final isCompleted = index < currentStep - 1;
    final isCurrent = index == currentStep - 1;
    final iconPath = (isCompleted || isCurrent)
        ? 'assets/high_security/step_indicator_active_icon.svg'
        : 'assets/high_security/step_indicator_icon.svg';

    return Center(child: SvgPicture.asset(iconPath, width: 4, height: iconHeight));
  }

  Widget _buildStepLine(BuildContext context, int index) {
    final isCompleted = index < currentStep - 1;
    final isCurrent = index == currentStep - 1;
    final lineColor = (isCompleted || isCurrent) ? context.themeColors.checksum : const Color(0x66FFFFFF);

    return Expanded(
      child: Container(height: lineHeight, color: lineColor),
    );
  }
}
