import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// The steps a private send's progress shows, each by the number its proving
/// reports it under and its name.
List<(int, String)> encryptedSendSteps(AppLocalizations l10n) => [
  (1, l10n.encryptedSendStepPreparing),
  (4, l10n.encryptedSendStepGenerating),
  (5, l10n.encryptedSendStepProving),
  (6, l10n.encryptedSendStepSubmitting),
];

/// Where each step of a wormhole operation stands, read off what the
/// operation has reported so far. Each app draws the steps its own way.
///
/// The steps before the fourth run one after another: one is done once a
/// later one has started. From the fourth on they overlap, batch by batch,
/// and each is done when it has reached its own total.
class WormholeStepStates {
  const WormholeStepStates({
    required this.stepProgress,
    required this.currentStep,
    required this.done,
    required this.cancelled,
    required this.hasError,
  });

  /// The latest report of each step that has made one.
  final Map<int, ClaimProgressItem> stepProgress;

  /// The step the latest report was of.
  final int currentStep;

  /// The operation finished; every step is done.
  final bool done;
  final bool cancelled;
  final bool hasError;

  static const int _firstOverlappingStep = 4;

  int get _lastStartedStep => stepProgress.keys.fold(currentStep, (last, step) => step > last ? step : last);

  bool _isCompleted(int step) {
    if (done) return true;
    if (step < _firstOverlappingStep) return _lastStartedStep > step;
    final progress = stepProgress[step];
    final total = progress?.total;
    return progress != null && total != null && progress.completed >= total;
  }

  /// The step has begun and has not finished, whether or not the operation
  /// still runs.
  bool _isUnderWay(int step) {
    if (_isCompleted(step)) return false;
    return step < _firstOverlappingStep ? currentStep == step : stepProgress[step] != null;
  }

  /// How [step] is to be shown. An error ends the step it came at; a cancel
  /// leaves the steps it interrupted pending, see [stoppedAt].
  StepRowState of(int step) {
    if (_isCompleted(step)) return StepRowState.done;
    if (hasError && currentStep == step) return StepRowState.ended;
    if (!cancelled && !hasError && _isUnderWay(step)) return StepRowState.active;
    return StepRowState.pending;
  }

  /// A cancel interrupted [step]: it had begun and had not finished.
  bool stoppedAt(int step) => cancelled && _isUnderWay(step);
}
