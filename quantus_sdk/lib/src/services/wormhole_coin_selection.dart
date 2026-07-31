import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

/// Wormhole circuit economics, shared by coin selection and the send service.
/// Values must match the chain runtime and the Rust wormhole API.
const int wormholeVolumeFeeBps = 10;

/// Scaled-down → token multiplier; matches `SCALE_DOWN_FACTOR` in the Rust
/// wormhole API. Proofs commit to amounts in scaled-down units (0.01 tokens) and
/// the chain dispatches `outputAmount * scaleFactor` token units.
final BigInt wormholeScaleFactor = BigInt.from(10000000000);

/// Chain's `MinimumTransferAmount` (0.1 token) in scaled units, enforced per
/// aggregated batch on the total exit amount.
const int wormholeMinBatchExitScaled = 10;

int wormholeScaledFromToken(BigInt token) => (token ~/ wormholeScaleFactor).toInt();

BigInt wormholeTokenFromScaled(int scaled) => BigInt.from(scaled) * wormholeScaleFactor;

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
  final BigInt amountToken;
  final BigInt changeToken;

  /// Everything consumed that neither the recipient nor the change receives:
  /// the 10 bps volume fee plus sub-0.01-tokens quantization dust.
  final BigInt feeToken;

  const WormholeSpendPlan({
    required this.batches,
    required this.amountToken,
    required this.changeToken,
    required this.feeToken,
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
  final BigInt maxSendableToken;
  InsufficientEncryptedFunds(this.maxSendableToken)
    : super('Insufficient encrypted funds: max sendable is $maxSendableToken token units');
}

/// An aggregation batch's total exit would fall below the chain's minimum
/// (0.1 token); the amounts are too fragmented to send this way.
class BatchBelowMinimumExit extends WormholeSelectionException {
  BatchBelowMinimumExit(int totalScaled)
    : super('Batch exit total $totalScaled is below the chain minimum of $wormholeMinBatchExitScaled (0.1 token)');
}

/// Maximum amount spendable from [utxos] (sum of per-input nets after the
/// volume fee), in token units.
BigInt wormholeMaxSendable(List<WormholeUtxo> utxos) {
  final totalScaled = utxos.fold<int>(0, (sum, u) => sum + wormholeNetScaled(wormholeScaledFromToken(u.amount)));
  return wormholeTokenFromScaled(totalScaled);
}

/// Selects inputs to send exactly [amountToken] (a multiple of 0.01 tokens) to
/// the recipient, largest-first. Every leaf pays its full net to the recipient
/// except the last, which splits between the recipient remainder and change.
/// Leaves are distributed round-robin (largest exits first) across the minimum
/// number of 7-proof batches so each batch clears the chain's minimum exit.
WormholeSpendPlan selectWormholeInputs({
  required List<WormholeUtxo> utxos,
  required BigInt amountToken,
  int maxProofsPerBatch = 7,
}) {
  if (amountToken <= BigInt.zero) {
    throw ArgumentError('amountToken must be positive, got $amountToken');
  }
  if (amountToken % wormholeScaleFactor != BigInt.zero) {
    throw ArgumentError('amountToken must be a multiple of 0.01 tokens, got $amountToken');
  }
  final targetScaled = wormholeScaledFromToken(amountToken);

  final candidates = utxos.where((u) => wormholeNetScaled(wormholeScaledFromToken(u.amount)) > 0).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final maxSendable = wormholeMaxSendable(candidates);
  if (wormholeTokenFromScaled(targetScaled) > maxSendable) {
    throw InsufficientEncryptedFunds(maxSendable);
  }

  final assignments = <WormholeLeafAssignment>[];
  var remaining = targetScaled;
  var consumedToken = BigInt.zero;
  for (final utxo in candidates) {
    final net = wormholeNetScaled(wormholeScaledFromToken(utxo.amount));
    final pay = net < remaining ? net : remaining;
    assignments.add(WormholeLeafAssignment(utxo: utxo, recipientScaled: pay, changeScaled: net - pay));
    consumedToken += utxo.amount;
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
  final changeToken = wormholeTokenFromScaled(changeScaled);
  return WormholeSpendPlan(
    batches: batches,
    amountToken: amountToken,
    changeToken: changeToken,
    feeToken: consumedToken - amountToken - changeToken,
  );
}
