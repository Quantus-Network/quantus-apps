import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/send/wormhole_steps.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(children: [for (final step in steps) _rowFor(step.$1, step.$2)]);
  }

  Widget _rowFor(int step, String title) {
    final progress = stepProgress[step];
    final state = WormholeStepStates(
      stepProgress: stepProgress,
      currentStep: currentStep,
      done: done,
      cancelled: cancelled,
      hasError: hasError,
    ).of(step);
    final substate = state == StepRowState.active && progress != null ? _substateFor(step, progress) : null;
    return QuantusStepRow(state: state, label: title, substate: substate);
  }

  String? _substateFor(int step, ClaimProgressItem progress) {
    final label =
        progressLabelOverride?.call(step, progress) ??
        (progress.total != null ? '${progress.completed} / ${progress.total}' : '');
    return label.isEmpty ? null : label;
  }
}
