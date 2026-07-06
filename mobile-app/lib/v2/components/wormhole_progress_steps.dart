import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Step list for wormhole proving flows (mining-rewards redeem and encrypted
/// send), rendering [ClaimProgressItem] updates from [WormholeSendService].
///
/// Steps 5 (generating proofs) and 6 (aggregating & submitting) run
/// interleaved batch-by-batch, so their state is driven by their own reported
/// progress rather than the linear current-step cursor: once step 6 is
/// reported it stays engaged (showing batches submitted) even while step 5
/// keeps advancing for the remaining batches.
class WormholeProgressSteps extends StatelessWidget {
  /// (service step id, localized title) in display order.
  final List<(int, String)> steps;
  final Map<int, ClaimProgressItem> stepProgress;
  final int currentStep;
  final bool done;
  final bool cancelled;
  final bool hasError;

  /// Optional per-step progress label override (e.g. "12 fetched" for the
  /// transfer-fetch step, which has no known total). Return null for the
  /// default "completed / total" label.
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

  /// Highest step that has reported progress (steps 5 & 6 interleave, so the
  /// linear cursor alone can't tell us which earlier steps are done).
  int get _maxStartedStep => stepProgress.keys.fold(currentStep, (m, k) => k > m ? k : m);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _buildStepRow(steps[i].$1, steps[i].$2, colors, text),
            if (i < steps.length - 1) _buildConnector(steps[i].$1, colors),
          ],
        ],
      ),
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
    } else if (step >= 5) {
      isCompleted = reachedTotal;
      isActive = progress != null && !reachedTotal && !cancelled && !hasError;
    } else {
      isCompleted = _maxStartedStep > step;
      isActive = !isCompleted && !cancelled && !hasError && currentStep == step;
    }

    final Widget icon;
    if (isCompleted) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (isError) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colors.textError.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: colors.textError, width: 2),
        ),
        child: Icon(Icons.close, color: colors.textError, size: 14),
      );
    } else if (isActive) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: colors.success, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.success),
        ),
      );
    } else {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.borderButton.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(
          child: Text('$step', style: text.detail?.copyWith(color: colors.textTertiary)),
        ),
      );
    }

    final titleColor = isCompleted
        ? colors.success
        : isActive
        ? colors.textPrimary
        : isError
        ? colors.textError
        : colors.textTertiary;

    String progressText = '';
    if (progress != null && (isActive || isCompleted)) {
      progressText =
          progressLabelOverride?.call(step, progress) ??
          (progress.total != null ? '${progress.completed} / ${progress.total}' : '');
    }

    double? progressFraction;
    if (isActive && progress != null && progress.total != null && progress.total! > 0) {
      progressFraction = (progress.completed / progress.total!).clamp(0.0, 1.0);
    }

    return Column(
      children: [
        Row(
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
                  color: isCompleted ? colors.success : colors.textPrimary,
                  fontFamily: AppTextTheme.fontFamilySecondary,
                ),
              ),
          ],
        ),
        if (progressFraction != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressFraction,
                backgroundColor: colors.borderButton.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(colors.success),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnector(int afterStep, AppColorsV2 colors) {
    final isCompleted = done ? true : currentStep > afterStep;
    return Padding(
      padding: const EdgeInsets.only(left: 13),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted ? colors.success.withValues(alpha: 0.4) : colors.borderButton.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
