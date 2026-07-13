import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class WormholeProgressSteps extends StatelessWidget {
  final List<(int, String)> steps;
  final Map<int, ClaimProgressItem> stepProgress;
  final int currentStep;
  final bool done;
  final bool cancelled;
  final bool hasError;
  final String? Function(int step, ClaimProgressItem progress)? progressLabelOverride;

  const WormholeProgressSteps({
    super.key,
    required this.steps,
    required this.stepProgress,
    required this.currentStep,
    required this.done,
    required this.cancelled,
    required this.hasError,
    this.progressLabelOverride,
  });

  int get _maxStartedStep => stepProgress.keys.fold(currentStep, (m, k) => k > m ? k : m);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _buildStepRow(steps[i].$1, steps[i].$2, colors, text),
      ],
    );
  }

  Widget _buildStepRow(int step, String title, AppColorsV2 colors, AppTextTheme text) {
    final progress = stepProgress[step];
    final isError = !done && hasError && currentStep == step;
    final reachedTotal = progress != null && progress.total != null && progress.completed >= progress.total!;

    final bool isCompleted;
    final bool isActive;
    if (done) {
      isCompleted = true;
      isActive = false;
    } else if (step >= 4) {
      isCompleted = reachedTotal;
      isActive = progress != null && !reachedTotal && !cancelled && !hasError;
    } else {
      isCompleted = _maxStartedStep > step;
      isActive = !isCompleted && !cancelled && !hasError && currentStep == step;
    }

    final Widget icon;
    if (isCompleted) {
      icon = SizedBox(
        width: 22,
        height: 22,
        child: Center(child: Icon(Icons.check, color: colors.success, size: 14)),
      );
    } else if (isError) {
      icon = SizedBox(
        width: 22,
        height: 22,
        child: Center(child: Icon(Icons.close, color: colors.textError, size: 14)),
      );
    } else if (isActive) {
      icon = SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.accentOrange, width: 1),
            ),
          ),
        ),
      );
    } else {
      icon = SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
      );
    }

    const pendingColor = Color(0xFF666666);
    final titleColor = isCompleted
        ? colors.textPrimary
        : isActive
            ? colors.textPrimary
            : isError
                ? colors.textError
                : pendingColor;

    String progressText = '';
    if (progress != null && isActive) {
      progressText =
          progressLabelOverride?.call(step, progress) ??
          (progress.total != null ? '${progress.completed} / ${progress.total}' : '');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: text.smallParagraph?.copyWith(color: titleColor)),
          ),
          if (progressText.isNotEmpty)
            Text(
              progressText,
              style: text.detail?.copyWith(
                color: pendingColor,
                fontFamily: AppTextTheme.fontFamilySecondary,
              ),
            ),
        ],
      ),
    );
  }
}
