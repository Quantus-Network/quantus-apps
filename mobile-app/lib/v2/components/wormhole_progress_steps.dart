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
    return Column(children: [for (final step in steps) _rowFor(step.$1, step.$2)]);
  }

  Widget _rowFor(int step, String title) {
    final progress = stepProgress[step];
    return QuantusStepRow(state: _stateFor(step, progress), label: title, substate: _substateFor(step, progress));
  }

  StepRowState _stateFor(int step, ClaimProgressItem? progress) {
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

    if (isCompleted) return StepRowState.done;
    if (isActive) return StepRowState.active;

    final isCurrentInFlight = currentStep == step || (step >= 4 && progress != null && !reachedTotal);
    if (!done && isCurrentInFlight && (hasError || cancelled)) {
      return StepRowState.ended;
    }

    return StepRowState.pending;
  }

  String? _substateFor(int step, ClaimProgressItem? progress) {
    if (progress == null) return null;
    final override = progressLabelOverride?.call(step, progress);
    if (override != null && override.isNotEmpty) return override;
    if (progress.total != null) return '${progress.completed} / ${progress.total}';
    return null;
  }
}
