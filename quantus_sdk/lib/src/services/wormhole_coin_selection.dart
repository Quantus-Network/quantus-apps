import 'package:quantus_sdk/generated/bell/pallets/vesting.dart' as vesting_pallet;
import 'package:quantus_sdk/generated/bell/pallets/wormhole.dart' as wormhole_pallet;
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

/// Production private-batch shape (`qp_wormhole_inputs::production`): burns
/// per private batch and exit slots per private batch. The circuit binaries'
/// `config.json` is the source of truth at send time; these are the planning
/// defaults and must match it.
const int wormholeDefaultLeafProofs = 9;
const int wormholeDefaultExitSlots = 32;

/// Max total output the circuit allows for a private batch:
/// `Σexits * 10000 <= Σinputs * (10000 - feeBps)`.
int wormholeNetScaled(int inputScaled) => inputScaled * (10000 - wormholeVolumeFeeBps) ~/ 10000;

/// Share of the volume fee the runtime mints to the block author when a
/// proof exits [exitsScaled] in total (`pallet_wormhole` settlement): the fee
/// is `ceil(exits * bps / (10000 - bps))` scaled units, of which
/// `ceil(VolumeFeesBurnRate * fee)` is burned and the rest minted to the
/// author. The indexer lists that mint as one more exit of the proof.
int wormholeMinerFeeShareScaled(int exitsScaled) {
  final denominator = 10000 - wormholeVolumeFeeBps;
  if (denominator <= 0) return 0;
  final fee = (exitsScaled * wormholeVolumeFeeBps + denominator - 1) ~/ denominator;
  final burned = (fee * _volumeFeesBurnRatePermill + 999999) ~/ 1000000;
  return fee - burned;
}

final int _volumeFeesBurnRatePermill = wormhole_pallet.Constants().volumeFeesBurnRate;

int wormholeBatchNetScaled(Iterable<int> inputAmounts) =>
    wormholeNetScaled(inputAmounts.fold(0, (sum, amount) => sum + amount));

// --- Denominated change ---

/// Smallest bill, in scaled units (1 token). Change below this is paid out as
/// a single remainder rather than split further: every bill is one more leaf
/// to prove when it is spent, so dust-sized bills cost more than they hide.
const int wormholeMinBillScaled = 100;

/// Bill denominations in scaled units, a 1-2-5 series from
/// [wormholeMinBillScaled] up to the largest value a leaf amount can hold
/// (u32 scaled units), descending.
final List<int> wormholeBillDenominationsScaled = _buildDenominations();

List<int> _buildDenominations() {
  const u32Max = 0xFFFFFFFF;
  final result = <int>[];
  var decade = wormholeMinBillScaled;
  while (decade <= u32Max) {
    for (final multiplier in const [1, 2, 5]) {
      final value = decade * multiplier;
      if (value <= u32Max) result.add(value);
    }
    decade *= 10;
  }
  return result.reversed.toList();
}

/// Splits [changeScaled] into standard-denomination bills (largest first, at
/// most [maxBills]) and a remainder below the smallest bill — or, when the
/// bill budget runs out, whatever is left.
({List<int> bills, int remainder}) denominateChange(int changeScaled, {required int maxBills}) {
  if (changeScaled < 0) throw ArgumentError.value(changeScaled, 'changeScaled', 'must be non-negative');
  final bills = <int>[];
  var remaining = changeScaled;
  for (final denomination in wormholeBillDenominationsScaled) {
    while (remaining >= denomination && bills.length < maxBills) {
      bills.add(denomination);
      remaining -= denomination;
    }
    if (bills.length >= maxBills) break;
  }
  return (bills: bills, remainder: remaining);
}

List<List<T>> _chunks<T>(List<T> values, int size) {
  if (size <= 0) throw ArgumentError.value(size, 'size', 'must be positive');
  return [for (var i = 0; i < values.length; i += size) values.sublist(i, (i + size).clamp(0, values.length))];
}

List<WormholeUtxo> _sortedSpendable(List<WormholeUtxo> utxos) =>
    utxos.where((utxo) => wormholeScaledFromToken(utxo.amount) > 0).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

int _scaled(WormholeUtxo utxo) => wormholeScaledFromToken(utxo.amount);

int _maxExitScaled(List<WormholeUtxo> sorted, int maxProofsPerBatch) =>
    _chunks(sorted, maxProofsPerBatch).fold<int>(0, (sum, batch) => sum + wormholeBatchNetScaled(batch.map(_scaled)));

/// One private batch of a send: its burns and how their net value is exited.
/// [recipientScaled] goes to the recipient; [billsScaled] and
/// [remainderScaled] return to the sender, each to its own fresh change
/// address (allocated at send time, not here).
class WormholeBatchPlan {
  final List<WormholeUtxo> inputs;
  final int recipientScaled;
  final List<int> billsScaled;
  final int remainderScaled;

  const WormholeBatchPlan({
    required this.inputs,
    required this.recipientScaled,
    this.billsScaled = const [],
    this.remainderScaled = 0,
  });

  int get inputScaled => inputs.fold(0, (sum, utxo) => sum + _scaled(utxo));

  int get changeScaled => billsScaled.fold(remainderScaled, (sum, bill) => sum + bill);

  /// Change amounts in exit order: bills, then the remainder when non-zero.
  List<int> get changeExitsScaled => [...billsScaled, if (remainderScaled > 0) remainderScaled];

  int get exitScaled => recipientScaled + changeScaled;

  /// Exit slots this batch occupies.
  int get exitCount => (recipientScaled > 0 ? 1 : 0) + changeExitsScaled.length;
}

class WormholeSpendPlan {
  /// Aggregation batches, each one extrinsic.
  final List<WormholeBatchPlan> batches;
  final BigInt amountToken;

  /// Everything returned to the sender: bills plus remainder.
  final BigInt changeToken;

  /// Everything consumed that neither the recipient nor the sender receives.
  final BigInt feeToken;

  const WormholeSpendPlan({
    required this.batches,
    required this.amountToken,
    required this.changeToken,
    required this.feeToken,
  });

  int get inputCount => batches.fold(0, (sum, b) => sum + b.inputs.length);

  /// Fresh change addresses the send needs: one per bill or remainder.
  int get changeOutputCount => batches.fold(0, (sum, b) => sum + b.changeExitsScaled.length);
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
BigInt wormholeMaxSendable(List<WormholeUtxo> utxos, {int maxProofsPerBatch = wormholeDefaultLeafProofs}) {
  return wormholeTokenFromScaled(_maxExitScaled(_sortedSpendable(utxos), maxProofsPerBatch));
}

/// Largest-first until the selection's net covers [targetScaled].
List<WormholeUtxo> _selectLargestFirst(List<WormholeUtxo> candidates, int targetScaled, int maxProofsPerBatch) {
  final selected = <WormholeUtxo>[];
  var completedBatchNet = 0;
  var currentBatchInput = 0;
  for (final utxo in candidates) {
    if (selected.isNotEmpty && selected.length % maxProofsPerBatch == 0) {
      completedBatchNet += wormholeNetScaled(currentBatchInput);
      currentBatchInput = 0;
    }
    selected.add(utxo);
    currentBatchInput += _scaled(utxo);
    if (completedBatchNet + wormholeNetScaled(currentBatchInput) >= targetScaled) break;
  }
  return selected;
}

/// The smallest single input whose net covers [targetScaled], if any.
List<WormholeUtxo>? _selectSmallestSufficient(List<WormholeUtxo> candidates, int targetScaled) {
  WormholeUtxo? best;
  for (final utxo in candidates) {
    if (wormholeNetScaled(_scaled(utxo)) >= targetScaled) best = utxo;
  }
  return best == null ? null : [best];
}

/// Best-fit selections within a single batch (one fee): a largest-first pass
/// that skips any input whose addition would overshoot the target, then, for
/// every prefix of that pass, the smallest remaining input that completes
/// it. Each lands close to the target, so little change is left to
/// denominate; the caller picks among them.
Iterable<List<WormholeUtxo>> _selectBestFit(
  List<WormholeUtxo> candidates,
  int targetScaled,
  int maxProofsPerBatch,
) sync* {
  final fitted = <WormholeUtxo>[];
  var input = 0;
  for (final utxo in candidates) {
    if (fitted.length >= maxProofsPerBatch) break;
    final next = input + _scaled(utxo);
    if (wormholeNetScaled(next) <= targetScaled) {
      fitted.add(utxo);
      input = next;
      if (wormholeNetScaled(input) == targetScaled) {
        yield fitted;
        return;
      }
    }
  }
  for (var length = fitted.length; length >= 0; length--) {
    if (length >= maxProofsPerBatch) continue;
    final prefix = fitted.sublist(0, length);
    final prefixInput = prefix.fold(0, (sum, utxo) => sum + _scaled(utxo));
    WormholeUtxo? completer;
    for (final utxo in candidates) {
      if (prefix.contains(utxo)) continue;
      if (wormholeNetScaled(prefixInput + _scaled(utxo)) >= targetScaled) completer = utxo;
    }
    if (completer != null) yield [...prefix, completer]..sort((a, b) => b.amount.compareTo(a.amount));
  }
}

/// Pays the recipient from each batch's net in order; the last batch carries
/// whatever is left as denominated change. Null when the selection cannot
/// hold its change within the exit-slot budget.
WormholeSpendPlan? _planFor(
  List<WormholeUtxo> selected,
  int targetScaled,
  BigInt amountToken,
  int maxProofsPerBatch,
  int maxExitSlots,
) {
  var remaining = targetScaled;
  final batches = <WormholeBatchPlan>[];
  for (final inputs in _chunks(selected, maxProofsPerBatch)) {
    final net = wormholeBatchNetScaled(inputs.map(_scaled));
    final pay = net < remaining ? net : remaining;
    remaining -= pay;
    final change = net - pay;
    if (change == 0) {
      batches.add(WormholeBatchPlan(inputs: inputs, recipientScaled: pay));
      continue;
    }
    final slotsForChange = maxExitSlots - (pay > 0 ? 1 : 0);
    // One slot is kept for the remainder so a bill budget that runs out
    // never leaves the leftover without a place to go.
    final (:bills, :remainder) = denominateChange(change, maxBills: slotsForChange - 1);
    final batch = WormholeBatchPlan(
      inputs: inputs,
      recipientScaled: pay,
      billsScaled: bills,
      remainderScaled: remainder,
    );
    if (batch.exitCount > maxExitSlots) return null;
    batches.add(batch);
  }
  if (remaining != 0) throw StateError('Selected wormhole inputs are short by $remaining scaled units');

  final changeScaled = batches.fold<int>(0, (sum, b) => sum + b.changeScaled);
  final changeToken = wormholeTokenFromScaled(changeScaled);
  final consumedToken = selected.fold(BigInt.zero, (sum, utxo) => sum + utxo.amount);
  return WormholeSpendPlan(
    batches: batches,
    amountToken: amountToken,
    changeToken: changeToken,
    feeToken: consumedToken - amountToken - changeToken,
  );
}

/// Fewest change exits first (each is a fresh address and a future leaf to
/// prove), then fewest inputs (each is a leaf proof now), then least change.
int _comparePlans(WormholeSpendPlan a, WormholeSpendPlan b) {
  final byChangeOutputs = a.changeOutputCount.compareTo(b.changeOutputCount);
  if (byChangeOutputs != 0) return byChangeOutputs;
  final byInputs = a.inputCount.compareTo(b.inputCount);
  if (byInputs != 0) return byInputs;
  return a.changeToken.compareTo(b.changeToken);
}

/// Selects inputs to send exactly [amountToken] (a multiple of 0.01 tokens) to
/// the recipient. The volume fee is deducted once per private batch; whatever
/// the batches net beyond the amount returns to the sender as standard
/// denomination bills plus a sub-bill remainder ([denominateChange]), so the
/// change leaves of a send are indistinguishable by amount from everyone
/// else's bills when they are spent later.
///
/// Several selections are tried and the one with the fewest change exits,
/// then fewest inputs, wins: largest-first (the baseline, always feasible),
/// the smallest single input that covers the amount, and best-fit passes
/// that land close to the amount.
WormholeSpendPlan selectWormholeInputs({
  required List<WormholeUtxo> utxos,
  required BigInt amountToken,
  int maxProofsPerBatch = wormholeDefaultLeafProofs,
  int maxExitSlots = wormholeDefaultExitSlots,
}) {
  if (amountToken <= BigInt.zero) {
    throw ArgumentError('amountToken must be positive, got $amountToken');
  }
  if (amountToken % wormholeScaleFactor != BigInt.zero) {
    throw ArgumentError('amountToken must be a multiple of 0.01 tokens, got $amountToken');
  }
  if (maxExitSlots < 2) throw ArgumentError.value(maxExitSlots, 'maxExitSlots', 'must allow recipient and change');
  final targetScaled = wormholeScaledFromToken(amountToken);

  final candidates = _sortedSpendable(utxos);
  final maxSendable = wormholeTokenFromScaled(_maxExitScaled(candidates, maxProofsPerBatch));
  if (wormholeTokenFromScaled(targetScaled) > maxSendable) {
    throw InsufficientEncryptedFunds(maxSendable);
  }

  final selections = <List<WormholeUtxo>>[
    _selectLargestFirst(candidates, targetScaled, maxProofsPerBatch),
    ?_selectSmallestSufficient(candidates, targetScaled),
    ..._selectBestFit(candidates, targetScaled, maxProofsPerBatch),
  ];
  final plans = [
    for (final selected in selections) ?_planFor(selected, targetScaled, amountToken, maxProofsPerBatch, maxExitSlots),
  ];
  if (plans.isEmpty) {
    throw StateError('No wormhole spend plan fits $maxExitSlots exit slots for $amountToken');
  }
  plans.sort(_comparePlans);
  return plans.first;
}
