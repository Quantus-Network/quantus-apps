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
    final state = _stateFor(step, progress);
    final substate = state == StepRowState.active && progress != null ? _substateFor(step, progress) : null;
    return QuantusStepRow(state: state, label: title, substate: substate);
  }

  StepRowState _stateFor(int step, ClaimProgressItem? progress) {
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

    if (isCompleted) return StepRowState.done;
    if (isError) return StepRowState.ended;
    if (isActive) return StepRowState.active;
    return StepRowState.pending;
  }

  String? _substateFor(int step, ClaimProgressItem progress) {
    final label =
        progressLabelOverride?.call(step, progress) ??
        (progress.total != null ? '${progress.completed} / ${progress.total}' : '');
    return label.isEmpty ? null : label;
  }
}
