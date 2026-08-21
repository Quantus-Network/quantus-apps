import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
      children: [for (int i = 0; i < steps.length; i++) _buildStepRow(steps[i].$1, steps[i].$2, colors, text)],
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

    final icon = _stepIcon(colors, isCompleted: isCompleted, isError: isError, isActive: isActive);

    final Color titleColor;
    if (isCompleted || isActive) {
      titleColor = colors.textPrimary;
    } else if (isError) {
      titleColor = colors.textError;
    } else {
      titleColor = colors.progressStepPendingText;
    }

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
                color: colors.progressStepPendingText,
                fontFamily: AppTextTheme.fontFamilySecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconBox(Widget child) => SizedBox(width: 22, height: 22, child: Center(child: child));

  Widget _stepIcon(AppColorsV2 colors, {required bool isCompleted, required bool isError, required bool isActive}) {
    if (isCompleted) return _iconBox(Icon(Icons.check, color: colors.success, size: 14));
    if (isError) return _iconBox(Icon(Icons.close, color: colors.textError, size: 14));
    if (isActive) {
      return _iconBox(
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.accentOrange, width: 1),
          ),
        ),
      );
    }
    return _iconBox(
      Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: colors.progressStepPendingDot, borderRadius: BorderRadius.circular(2.5)),
      ),
    );
  }
}
