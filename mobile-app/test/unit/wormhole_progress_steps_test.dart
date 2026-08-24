import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/wormhole_progress_steps.dart';

import '../extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const labels = [(1, 'Preparing'), (4, 'Generate proofs'), (5, 'Building privacy proof'), (6, 'Submitting to chain')];

  Future<void> pumpSteps(
    WidgetTester tester, {
    Map<int, ClaimProgressItem> stepProgress = const {},
    int currentStep = 0,
    bool done = false,
    bool cancelled = false,
    bool hasError = false,
    String? Function(int step, ClaimProgressItem progress)? progressLabelOverride,
  }) {
    return tester.pumpApp(
      WormholeProgressSteps(
        steps: labels,
        stepProgress: stepProgress,
        currentStep: currentStep,
        done: done,
        cancelled: cancelled,
        hasError: hasError,
        progressLabelOverride: progressLabelOverride,
      ),
    );
  }

  List<QuantusStepRow> rows(WidgetTester tester) {
    return tester.widgetList<QuantusStepRow>(find.byType(QuantusStepRow)).toList();
  }

  ClaimProgressItem item(int step, {required int completed, int? total}) {
    return ClaimProgressItem(step: step, title: 'step $step', completed: completed, total: total);
  }

  testWidgets('in-flight step 4 with remaining work is active and shows count substate', (tester) async {
    await pumpSteps(tester, currentStep: 4, stepProgress: {4: item(4, completed: 2, total: 4)});

    final row = rows(tester).singleWhere((r) => r.label == 'Generate proofs');
    expect(row.state, StepRowState.active);
    expect(row.substate, '2 / 4');
  });

  testWidgets('step 4 that reached total is done', (tester) async {
    await pumpSteps(tester, currentStep: 5, stepProgress: {4: item(4, completed: 4, total: 4)});

    final row = rows(tester).singleWhere((r) => r.label == 'Generate proofs');
    expect(row.state, StepRowState.done);
  });

  testWidgets('hasError on the current step maps to ended', (tester) async {
    await pumpSteps(tester, currentStep: 5, hasError: true, stepProgress: {5: item(5, completed: 1, total: 3)});

    final row = rows(tester).singleWhere((r) => r.label == 'Building privacy proof');
    expect(row.state, StepRowState.ended);
  });

  testWidgets('cancelled in-flight current step maps to ended', (tester) async {
    await pumpSteps(tester, currentStep: 5, cancelled: true, stepProgress: {5: item(5, completed: 1, total: 3)});

    final row = rows(tester).singleWhere((r) => r.label == 'Building privacy proof');
    expect(row.state, StepRowState.ended);
  });

  testWidgets('later steps stay pending while an earlier step is active', (tester) async {
    await pumpSteps(tester, currentStep: 4, stepProgress: {4: item(4, completed: 1, total: 2)});

    final submitting = rows(tester).singleWhere((r) => r.label == 'Submitting to chain');
    expect(submitting.state, StepRowState.pending);
  });

  testWidgets('progressLabelOverride is passed as QuantusStepRow substate', (tester) async {
    await tester.pumpApp(
      WormholeProgressSteps(
        steps: const [(1, 'Loading circuits'), (2, 'Fetching transfers')],
        stepProgress: {2: item(2, completed: 7)},
        currentStep: 2,
        done: false,
        cancelled: false,
        hasError: false,
        progressLabelOverride: (step, progress) => step == 2 ? '${progress.completed} fetched' : null,
      ),
    );

    final row = rows(tester).singleWhere((r) => r.label == 'Fetching transfers');
    expect(row.state, StepRowState.active);
    expect(row.substate, '7 fetched');
  });
}
