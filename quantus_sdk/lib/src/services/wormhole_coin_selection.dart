import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

/// Wormhole circuit economics, shared by coin selection and the send service.
/// Values must match the chain runtime and the Rust wormhole API.
const int wormholeVolumeFeeBps = 10;

/// Scaled-down → planck multiplier; matches `SCALE_DOWN_FACTOR` in the Rust
/// wormhole API. Proofs commit to amounts in scaled-down units (0.01 QUAN) and
/// the chain dispatches `outputAmount * scaleFactor` planck.
final BigInt wormholeScaleFactor = BigInt.from(10000000000);

/// Chain's `MinimumTransferAmount` (0.1 QUAN) in scaled units, enforced per
/// aggregated batch on the total exit amount.
const int wormholeMinBatchExitScaled = 10;

int wormholeScaledFromPlanck(BigInt planck) => (planck ~/ wormholeScaleFactor).toInt();

BigInt wormholePlanckFromScaled(int scaled) => BigInt.from(scaled) * wormholeScaleFactor;

/// Max total output the circuit allows for a consumed input:
/// `(out1 + out2) * 10000 <= input * (10000 - feeBps)`.
int wormholeNetScaled(int inputScaled) => inputScaled * (10000 - wormholeVolumeFeeBps) ~/ 10000;

/// One leaf proof's spend: consumes [utxo] entirely, pays [recipientScaled] to
/// the recipient (exit slot 1) and [changeScaled] back to the sender's fresh
/// change address (exit slot 2, zero when unused).
class WormholeLeafAssignment {
  final WormholeUtxo utxo;
  final int recipientScaled;
  final int changeScaled;

  const WormholeLeafAssignment({required this.utxo, required this.recipientScaled, required this.changeScaled});

  int get exitScaled => recipientScaled + changeScaled;
}

class WormholeSpendPlan {
  /// Leaf assignments grouped into aggregation batches (each one extrinsic).
  final List<List<WormholeLeafAssignment>> batches;
  final BigInt amountPlanck;
  final BigInt changePlanck;

  /// Everything consumed that neither the recipient nor the change receives:
  /// the 10 bps volume fee plus sub-0.01-QUAN quantization dust.
  final BigInt feePlanck;

  const WormholeSpendPlan({
    required this.batches,
    required this.amountPlanck,
    required this.changePlanck,
    required this.feePlanck,
  });

  int get inputCount => batches.fold(0, (sum, b) => sum + b.length);
}

sealed class WormholeSelectionException implements Exception {
  final String message;
  const WormholeSelectionException(this.message);
  @override
  String toString() => message;
}

class InsufficientEncryptedFunds extends WormholeSelectionException {
  final BigInt maxSendablePlanck;
  InsufficientEncryptedFunds(this.maxSendablePlanck)
    : super('Insufficient encrypted funds: max sendable is $maxSendablePlanck planck');
}

/// An aggregation batch's total exit would fall below the chain's minimum
/// (0.1 QUAN); the amounts are too fragmented to send this way.
class BatchBelowMinimumExit extends WormholeSelectionException {
  BatchBelowMinimumExit(int totalScaled)
    : super('Batch exit total $totalScaled is below the chain minimum of $wormholeMinBatchExitScaled (0.1 QUAN)');
}

/// Maximum amount spendable from [utxos] (sum of per-input nets after the
/// volume fee), in planck.
BigInt wormholeMaxSendable(List<WormholeUtxo> utxos) {
  final totalScaled = utxos.fold<int>(0, (sum, u) => sum + wormholeNetScaled(wormholeScaledFromPlanck(u.amount)));
  return wormholePlanckFromScaled(totalScaled);
}

/// Selects inputs to send exactly [amountPlanck] (a multiple of 0.01 QUAN) to
/// the recipient, largest-first. Every leaf pays its full net to the recipient
/// except the last, which splits between the recipient remainder and change.
/// Leaves are distributed round-robin (largest exits first) across the minimum
/// number of 7-proof batches so each batch clears the chain's minimum exit.
WormholeSpendPlan selectWormholeInputs({
  required List<WormholeUtxo> utxos,
  required BigInt amountPlanck,
  int maxProofsPerBatch = 7,
}) {
  if (amountPlanck <= BigInt.zero) {
    throw ArgumentError('amountPlanck must be positive, got $amountPlanck');
  }
  if (amountPlanck % wormholeScaleFactor != BigInt.zero) {
    throw ArgumentError('amountPlanck must be a multiple of 0.01 QUAN, got $amountPlanck');
  }
  final targetScaled = wormholeScaledFromPlanck(amountPlanck);

  final candidates = utxos.where((u) => wormholeNetScaled(wormholeScaledFromPlanck(u.amount)) > 0).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final maxSendable = wormholeMaxSendable(candidates);
  if (wormholePlanckFromScaled(targetScaled) > maxSendable) {
    throw InsufficientEncryptedFunds(maxSendable);
  }

  final assignments = <WormholeLeafAssignment>[];
  var remaining = targetScaled;
  var consumedPlanck = BigInt.zero;
  for (final utxo in candidates) {
    final net = wormholeNetScaled(wormholeScaledFromPlanck(utxo.amount));
    final pay = net < remaining ? net : remaining;
    assignments.add(WormholeLeafAssignment(utxo: utxo, recipientScaled: pay, changeScaled: net - pay));
    consumedPlanck += utxo.amount;
    remaining -= pay;
    if (remaining == 0) break;
  }

  final numBatches = (assignments.length + maxProofsPerBatch - 1) ~/ maxProofsPerBatch;
  final byExitDesc = [...assignments]..sort((a, b) => b.exitScaled.compareTo(a.exitScaled));
  final batches = List.generate(numBatches, (_) => <WormholeLeafAssignment>[]);
  for (var i = 0; i < byExitDesc.length; i++) {
    batches[i % numBatches].add(byExitDesc[i]);
  }
  for (final batch in batches) {
    final totalScaled = batch.fold<int>(0, (sum, a) => sum + a.exitScaled);
    if (totalScaled < wormholeMinBatchExitScaled) throw BatchBelowMinimumExit(totalScaled);
  }

  final changeScaled = assignments.fold<int>(0, (sum, a) => sum + a.changeScaled);
  final changePlanck = wormholePlanckFromScaled(changeScaled);
  return WormholeSpendPlan(
    batches: batches,
    amountPlanck: amountPlanck,
    changePlanck: changePlanck,
    feePlanck: consumedPlanck - amountPlanck - changePlanck,
  );
}
