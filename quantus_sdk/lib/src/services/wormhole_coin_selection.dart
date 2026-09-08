import 'package:quantus_sdk/generated/planck/pallets/vesting.dart' as vesting_pallet;
import 'package:quantus_sdk/generated/planck/pallets/wormhole.dart' as wormhole_pallet;
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

/// Wormhole circuit economics, shared by coin selection and the send service.
/// The fee is the runtime's own `Wormhole::VolumeFeeRateBps`, taken from the
/// metadata the app ships with (the generated pallet constants) and passed
/// unchanged to the Rust proof API — a runtime that changes it needs
/// regenerated bindings (`melos run generate`), never a hand-edited value.
final int wormholeVolumeFeeBps = wormhole_pallet.Constants().volumeFeeRateBps;

String wormholeVolumeFeePercentText() {
  final percent = wormholeVolumeFeeBps / 100;
  return percent == percent.truncateToDouble() ? percent.toInt().toString() : percent.toString();
}

/// Scaled-down → token multiplier (`SCALE_DOWN_FACTOR` in the Rust wormhole
/// API). Proofs commit to amounts in scaled-down units (0.01 tokens) and the
/// chain dispatches `outputAmount * scaleFactor` token units. The wormhole
/// pallet exposes no constant for it, so this comes from the shipped metadata's
/// `Vesting::PayoutQuantum`, which the runtime defines as
/// `pallet_wormhole::SCALE_DOWN_FACTOR` — same rule as the volume fee above,
/// never a hand-edited value.
final BigInt wormholeScaleFactor = vesting_pallet.Constants().payoutQuantum;

int wormholeScaledFromToken(BigInt token) => (token ~/ wormholeScaleFactor).toInt();

BigInt wormholeTokenFromScaled(int scaled) => BigInt.from(scaled) * wormholeScaleFactor;

/// Max total output the circuit allows for a private batch:
/// `(out1 + out2) * 10000 <= input * (10000 - feeBps)`.
int wormholeNetScaled(int inputScaled) => inputScaled * (10000 - wormholeVolumeFeeBps) ~/ 10000;

int wormholeBatchNetScaled(Iterable<int> inputAmounts) =>
    wormholeNetScaled(inputAmounts.fold(0, (sum, amount) => sum + amount));

List<int> wormholeBatchOutputs(List<int> inputAmounts) {
  if (inputAmounts.any((amount) => amount < 0)) throw ArgumentError('Wormhole batch inputs must be non-negative');
  final outputs = [...inputAmounts];
  var fee = outputs.fold(0, (sum, amount) => sum + amount) - wormholeBatchNetScaled(outputs);
  for (var i = outputs.length - 1; i >= 0 && fee > 0; i--) {
    final deduction = outputs[i] < fee ? outputs[i] : fee;
    outputs[i] -= deduction;
    fee -= deduction;
  }
  if (fee != 0) throw StateError('Unable to allocate wormhole batch fee');
  return outputs;
}

List<List<T>> _chunks<T>(List<T> values, int size) {
  if (size <= 0) throw ArgumentError.value(size, 'size', 'must be positive');
  return [for (var i = 0; i < values.length; i += size) values.sublist(i, (i + size).clamp(0, values.length))];
}

List<WormholeUtxo> _sortedSpendable(List<WormholeUtxo> utxos) =>
    utxos.where((utxo) => wormholeScaledFromToken(utxo.amount) > 0).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

int _maxExitScaled(List<WormholeUtxo> sorted, int maxProofsPerBatch) => _chunks(
  sorted,
  maxProofsPerBatch,
).fold<int>(0, (sum, batch) => sum + wormholeBatchNetScaled(batch.map((utxo) => wormholeScaledFromToken(utxo.amount))));

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

  /// Everything consumed that neither the recipient nor the change receives.
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

/// Maximum amount spendable from [utxos] after one fee per private batch.
BigInt wormholeMaxSendable(List<WormholeUtxo> utxos, {int maxProofsPerBatch = 7}) {
  return wormholeTokenFromScaled(_maxExitScaled(_sortedSpendable(utxos), maxProofsPerBatch));
}

/// Selects inputs to send exactly [amountToken] (a multiple of 0.01 tokens) to
/// the recipient, largest-first. The volume fee is deducted once per private
/// batch; any remaining output returns to the sender as change.
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

  final candidates = _sortedSpendable(utxos);
  final maxSendable = wormholeTokenFromScaled(_maxExitScaled(candidates, maxProofsPerBatch));
  if (wormholeTokenFromScaled(targetScaled) > maxSendable) {
    throw InsufficientEncryptedFunds(maxSendable);
  }

  final selected = <WormholeUtxo>[];
  var completedBatchNet = 0;
  var currentBatchInput = 0;
  for (final utxo in candidates) {
    if (selected.isNotEmpty && selected.length % maxProofsPerBatch == 0) {
      completedBatchNet += wormholeNetScaled(currentBatchInput);
      currentBatchInput = 0;
    }
    selected.add(utxo);
    currentBatchInput += wormholeScaledFromToken(utxo.amount);
    if (completedBatchNet + wormholeNetScaled(currentBatchInput) >= targetScaled) break;
  }

  var remaining = targetScaled;
  final batches = <List<WormholeLeafAssignment>>[];
  for (final inputs in _chunks(selected, maxProofsPerBatch)) {
    final outputAmounts = wormholeBatchOutputs(inputs.map((u) => wormholeScaledFromToken(u.amount)).toList());
    final batch = <WormholeLeafAssignment>[];
    for (var i = 0; i < inputs.length; i++) {
      final pay = outputAmounts[i] < remaining ? outputAmounts[i] : remaining;
      batch.add(WormholeLeafAssignment(utxo: inputs[i], recipientScaled: pay, changeScaled: outputAmounts[i] - pay));
      remaining -= pay;
    }
    batches.add(batch);
  }
  if (remaining != 0) throw StateError('Selected wormhole inputs are short by $remaining scaled units');

  final assignments = batches.expand((batch) => batch);
  final changeScaled = assignments.fold<int>(0, (sum, a) => sum + a.changeScaled);
  final changeToken = wormholeTokenFromScaled(changeScaled);
  final consumedToken = selected.fold(BigInt.zero, (sum, utxo) => sum + utxo.amount);
  return WormholeSpendPlan(
    batches: batches,
    amountToken: amountToken,
    changeToken: changeToken,
    feeToken: consumedToken - amountToken - changeToken,
  );
}
