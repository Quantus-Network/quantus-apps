import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/send/wormhole_steps.dart';

ClaimProgressItem _item(int step, {required int completed, int? total}) =>
    ClaimProgressItem(step: step, title: 'step $step', completed: completed, total: total);

WormholeStepStates _states({
  Map<int, ClaimProgressItem> stepProgress = const {},
  int currentStep = 0,
  bool done = false,
  bool cancelled = false,
  bool hasError = false,
}) => WormholeStepStates(
  stepProgress: stepProgress,
  currentStep: currentStep,
  done: done,
  cancelled: cancelled,
  hasError: hasError,
);

void main() {
  test('a private send shows four steps, by the numbers its proving reports them under', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(encryptedSendSteps(l10n), [
      (1, 'Preparing'),
      (4, 'Generate proofs'),
      (5, 'Building privacy proof'),
      (6, 'Submitting to chain'),
    ]);
  });

  group('the state of a step', () {
    test('a late step with work left is active', () {
      final states = _states(currentStep: 4, stepProgress: {4: _item(4, completed: 2, total: 4)});

      expect(states.of(4), StepRowState.active);
    });

    test('an early step is active while it is the current one, with or without progress', () {
      expect(_states(currentStep: 1).of(1), StepRowState.active);
    });

    test('an early step is done once a later one has started', () {
      final states = _states(currentStep: 4, stepProgress: {4: _item(4, completed: 0, total: 4)});

      expect(states.of(1), StepRowState.done);
    });

    test('a late step that reached its total is done', () {
      final states = _states(currentStep: 5, stepProgress: {4: _item(4, completed: 4, total: 4)});

      expect(states.of(4), StepRowState.done);
    });

    test('a late step nothing was reported for is pending, also while an earlier one is active', () {
      final states = _states(currentStep: 4, stepProgress: {4: _item(4, completed: 1, total: 2)});

      expect(states.of(5), StepRowState.pending);
      expect(states.of(6), StepRowState.pending);
    });

    test('an error ends the current step, and only that one', () {
      final states = _states(
        currentStep: 6,
        hasError: true,
        stepProgress: {
          4: _item(4, completed: 2, total: 4),
          5: _item(5, completed: 1, total: 2),
          6: _item(6, completed: 0, total: 2),
        },
      );

      expect(states.of(4), StepRowState.pending);
      expect(states.of(5), StepRowState.pending);
      expect(states.of(6), StepRowState.ended);
    });

    test('a step that finished before an error stays done', () {
      final states = _states(
        currentStep: 5,
        hasError: true,
        stepProgress: {4: _item(4, completed: 4, total: 4), 5: _item(5, completed: 1, total: 3)},
      );

      expect(states.of(1), StepRowState.done);
      expect(states.of(4), StepRowState.done);
      expect(states.of(5), StepRowState.ended);
    });

    test('a cancelled step in flight is pending', () {
      final states = _states(currentStep: 5, cancelled: true, stepProgress: {5: _item(5, completed: 1, total: 3)});

      expect(states.of(5), StepRowState.pending);
    });

    test('once the operation is done every step is', () {
      final states = _states(done: true, currentStep: 5, stepProgress: {5: _item(5, completed: 1, total: 3)});

      expect([1, 4, 5, 6].map(states.of), everyElement(StepRowState.done));
    });
  });

  group('where a cancel stopped', () {
    test('every late step that had started and not finished', () {
      final states = _states(
        currentStep: 5,
        cancelled: true,
        stepProgress: {
          4: _item(4, completed: 4, total: 4),
          5: _item(5, completed: 1, total: 3),
          6: _item(6, completed: 0, total: 3),
        },
      );

      expect(states.stoppedAt(1), isFalse);
      expect(states.stoppedAt(4), isFalse);
      expect(states.stoppedAt(5), isTrue);
      expect(states.stoppedAt(6), isTrue);
    });

    test('an early step that was the current one', () {
      final states = _states(currentStep: 1, cancelled: true);

      expect(states.stoppedAt(1), isTrue);
      expect(states.stoppedAt(4), isFalse);
    });

    test('nowhere while it runs, after an error, or once done', () {
      final progress = {5: _item(5, completed: 1, total: 3)};

      expect(_states(currentStep: 5, stepProgress: progress).stoppedAt(5), isFalse);
      expect(_states(currentStep: 5, hasError: true, stepProgress: progress).stoppedAt(5), isFalse);
      expect(_states(currentStep: 5, done: true, cancelled: true, stepProgress: progress).stoppedAt(5), isFalse);
    });
  });
}
