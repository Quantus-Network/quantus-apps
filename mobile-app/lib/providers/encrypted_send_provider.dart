import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Where an encrypted send operation currently stands.
enum EncryptedSendPhase {
  /// No operation started yet.
  idle,

  /// Proving/submitting is in flight.
  running,

  /// Cancel requested; waiting for the operation to reach a safe stop.
  canceling,

  /// Stopped before completion. [EncryptedSendState.submittedRecipientPlanck]
  /// is non-zero when some batches had already paid out.
  cancelled,

  /// The plan's inputs were spent between review and confirm; nothing was
  /// submitted. The user must re-enter the amount.
  planStale,

  /// Failed with [EncryptedSendState.errorMessage]; some batches may have
  /// been submitted before the failure (the message says so).
  failed,

  /// All batches submitted.
  succeeded,
}

@immutable
class EncryptedSendState {
  final EncryptedSendPhase phase;
  final int currentStep;
  final Map<int, ClaimProgressItem> stepProgress;
  final String? errorMessage;

  /// Amount already paid to the recipient by batches submitted before a
  /// cancellation (zero for a clean cancel).
  final BigInt submittedRecipientPlanck;

  EncryptedSendState({
    required this.phase,
    this.currentStep = 0,
    this.stepProgress = const {},
    this.errorMessage,
    BigInt? submittedRecipientPlanck,
  }) : submittedRecipientPlanck = submittedRecipientPlanck ?? BigInt.zero;

  bool get isRunning => phase == EncryptedSendPhase.running || phase == EncryptedSendPhase.canceling;

  EncryptedSendState copyWith({
    EncryptedSendPhase? phase,
    int? currentStep,
    Map<int, ClaimProgressItem>? stepProgress,
    String? errorMessage,
    BigInt? submittedRecipientPlanck,
  }) => EncryptedSendState(
    phase: phase ?? this.phase,
    currentStep: currentStep ?? this.currentStep,
    stepProgress: stepProgress ?? this.stepProgress,
    errorMessage: errorMessage ?? this.errorMessage,
    submittedRecipientPlanck: submittedRecipientPlanck ?? this.submittedRecipientPlanck,
  );
}

/// Owns one encrypted send operation end to end: plan revalidation, proving,
/// submission, cancellation and the resulting phase transitions. The progress
/// screen is a renderer over this state; the widget tree never holds the
/// operation itself, so navigation or session teardown cannot orphan it —
/// disposal cancels the underlying service operation.
class EncryptedSendController extends Notifier<EncryptedSendState> {
  EncryptedAccountService? _service;

  @override
  EncryptedSendState build() {
    ref.onDispose(() {
      // Fire-and-forget: WormholeSendService.cancel() is a no-op when the
      // operation already finished, and EncryptedAccountService gates all
      // persistence behind its own lifecycle, so a late stop is safe.
      final service = _service;
      if (service != null) unawaited(service.cancel());
    });
    return EncryptedSendState(phase: EncryptedSendPhase.idle);
  }

  /// Starts the send. Call exactly once per controller lifetime.
  Future<void> start({
    required Account account,
    required WormholeSpendPlan plan,
    required String recipientAddress,
  }) async {
    if (state.phase != EncryptedSendPhase.idle) return;
    state = state.copyWith(phase: EncryptedSendPhase.running);

    final walletIndex = account.walletIndex;
    final service = ref.read(encryptedAccountServiceProvider(walletIndex));
    _service = service;

    try {
      // The plan was frozen at fee-estimate time; UTXO spendability can have
      // changed while the user dwelled on review. Re-load and verify every
      // planned input is still unspent so a stale plan fails fast here
      // instead of after minutes of proving.
      final fresh = await service.load();
      final spendable = fresh.utxos.map((u) => u.nullifierHex).toSet();
      final planIsStale = plan.batches.any((batch) => batch.any((a) => !spendable.contains(a.utxo.nullifierHex)));
      if (planIsStale) {
        if (!ref.mounted) return;
        state = state.copyWith(phase: EncryptedSendPhase.planStale);
        return;
      }

      final circuitDir = await CircuitManager.getCircuitDirectory();
      final result = await service.send(
        plan: plan,
        recipientAddress: recipientAddress,
        circuitBinsDir: circuitDir,
        onProgress: (progress) {
          if (!ref.mounted) return;
          state = state.copyWith(
            currentStep: progress.step,
            stepProgress: {...state.stepProgress, progress.step: progress},
          );
        },
      );

      if (!ref.mounted) return;
      ref.invalidate(encryptedStateProvider(walletIndex));
      if (result.cancelled) {
        // Cancelled after some batches had already paid out: report the
        // partial outcome, never a clean "cancelled".
        state = state.copyWith(
          phase: EncryptedSendPhase.cancelled,
          submittedRecipientPlanck: result.totalWithdrawn,
        );
        return;
      }

      unawaited(
        RecentAddressesService()
            .addAddress(recipientAddress)
            .catchError((Object e) => debugPrint('Failed to save recent address: $e')),
      );
      state = state.copyWith(phase: EncryptedSendPhase.succeeded);
    } on ClaimCancelled {
      // Nothing was submitted.
      if (!ref.mounted) return;
      ref.invalidate(encryptedStateProvider(walletIndex));
      state = state.copyWith(phase: EncryptedSendPhase.cancelled);
    } catch (e) {
      debugPrint('[EncryptedSend] Send failed: $e');
      if (!ref.mounted) return;
      ref.invalidate(encryptedStateProvider(walletIndex));
      state = state.copyWith(phase: EncryptedSendPhase.failed, errorMessage: e.toString());
    }
  }

  /// Requests cancellation and waits for the operation to actually stop. The
  /// terminal phase (clean cancel, partial, or even success when the cancel
  /// arrived too late) is set by [start] from the operation's true outcome.
  Future<void> cancel() async {
    if (state.phase != EncryptedSendPhase.running) return;
    state = state.copyWith(phase: EncryptedSendPhase.canceling);
    await _service?.cancel();
  }
}

/// Auto-disposed: state lives exactly as long as a progress screen (or any
/// other listener) is watching it, and disposal cancels the operation.
final encryptedSendControllerProvider = NotifierProvider.autoDispose<EncryptedSendController, EncryptedSendState>(
  EncryptedSendController.new,
);
