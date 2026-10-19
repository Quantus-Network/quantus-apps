import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:quantus_sdk/src/models/event_type.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// The batches of one send are proved and submitted back to back, a couple of
/// minutes apart; batches further apart than this belong to different sends.
const Duration wormholeSendMergeWindow = Duration(minutes: 5);

/// One proof extrinsic of a send: the wallet's [inputs] it consumed (each
/// carrying the nullifier that spent it) and how their value was exited.
class WormholeSendBatch {
  final String extrinsicId;
  final int blockHeight;
  final DateTime timestamp;
  final List<WormholeUtxo> inputs;
  final BigInt sentToken;
  final BigInt changeToken;
  final BigInt feeToken;

  const WormholeSendBatch({
    required this.extrinsicId,
    required this.blockHeight,
    required this.timestamp,
    required this.inputs,
    required this.sentToken,
    required this.changeToken,
    required this.feeToken,
  });
}

/// A transfer settled by a wormhole proof: an encrypted send, or a receipt paid
/// out of someone else's. The explorer shows these under
/// `transactions/wormhole/<extrinsic>`.
class WormholeTransferEvent extends TransferEvent {
  /// The proof extrinsics of a send, in chain order; empty for a receipt.
  final List<WormholeSendBatch> batches;

  WormholeTransferEvent({
    required super.id,
    required super.from,
    required super.to,
    required super.amount,
    required super.timestamp,
    required super.fee,
    required super.extrinsicHash,
    required super.blockNumber,
    this.batches = const [],
  }) : super(blockHash: null);

  /// A payout of someone else's proof, as chain history lists it.
  WormholeTransferEvent.receipt(TransferEvent transfer)
    : this(
        id: transfer.id,
        from: transfer.from,
        to: transfer.to,
        amount: transfer.amount,
        timestamp: transfer.timestamp,
        fee: transfer.fee,
        extrinsicHash: transfer.extrinsicHash,
        blockNumber: transfer.blockNumber,
      );

  /// The inverse of [toJson].
  factory WormholeTransferEvent.fromJson(Map<String, dynamic> json) =>
      WormholeTransferEvent.receipt(TransferEvent.fromJson(json));

  /// Only a receipt serialises: a send's batches carry its inputs' secrets.
  @override
  Map<String, dynamic> toJson() {
    if (batches.isNotEmpty) throw StateError('a wormhole send is not serialisable');
    return {...super.toJson(), 'type': EventType.WORMHOLE_TRANSFER.name};
  }

  /// True for a spend whose proof settled together with other transfers, so
  /// the indexer cannot say which exit was ours: [amount] is what our inputs
  /// contributed and [to] is empty.
  bool get recipientUnknown => to.isEmpty;
}

/// One proof extrinsic that consumed inputs of this wallet. [recipient] is
/// null when its exits cannot be attributed to this wallet.
class _Batch {
  final WormholeSpend spend;
  final List<WormholeUtxo> inputs;
  final String? recipient;
  final BigInt sentToken;
  final BigInt changeToken;

  /// Exits that returned change to us; a transfer with one of these ids is
  /// that change, not a receipt.
  final Set<String> changeExitIds;
  final BigInt feeToken;

  const _Batch({
    required this.spend,
    required this.inputs,
    required this.recipient,
    required this.sentToken,
    required this.changeToken,
    required this.changeExitIds,
    required this.feeToken,
  });

  bool get attributed => recipient != null;

  bool get hasChange => changeToken > BigInt.zero;

  /// Chain position of the newest input this batch consumed.
  String get newestInput => inputs.map((u) => u.transfer.id).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

  WormholeSendBatch get detail => WormholeSendBatch(
    extrinsicId: spend.extrinsicId,
    blockHeight: spend.blockHeight,
    timestamp: spend.timestamp,
    inputs: inputs,
    sentToken: sentToken,
    changeToken: changeToken,
    feeToken: feeToken,
  );
}

/// The exit of [spend] that is the block author's share of the volume fee,
/// or null when there is none (the share rounded to nothing, the mint was
/// skipped, or the spend was cached before block authors were recorded).
///
/// The runtime computes the share from the other exits alone
/// ([wormholeMinerFeeShareScaled]), so an exit to the author is the share
/// exactly when its amount is what the remaining exits call for. A payment
/// to the author's account of any other size is a payment. The share is the
/// last leaf the runtime inserts, so among equal candidates the latest wins.
@visibleForTesting
WormholeOutput? feeShareOf(WormholeSpend spend) {
  final author = spend.blockAuthor;
  if (author == null) return null;
  final total = spend.outputs.fold(BigInt.zero, (sum, o) => sum + o.amount);
  WormholeOutput? share;
  for (final o in spend.outputs) {
    if (o.exitAccountId != author) continue;
    final expected = wormholeTokenFromScaled(wormholeMinerFeeShareScaled(wormholeScaledFromToken(total - o.amount)));
    if (expected > BigInt.zero && o.amount == expected && (share == null || o.id.compareTo(share.id) > 0)) share = o;
  }
  return share;
}

/// A send of this wallet is a private batch — one client's proof, and only
/// the holder of our secrets can put our leaves in one — that exits to exactly
/// one address that is not our own, plus optional change: every exit then
/// came from our inputs, so the ones to our own addresses are change.
/// Anything else (a public batch bundling several clients' proofs, or an exit
/// larger than our inputs) is reported by the full amount our inputs
/// contributed, with no recipient; nothing in such a proof is taken for
/// change, so a payment to us inside it stays a receipt.
///
/// The block author's share of the volume fee ([feeShareOf]) is neither
/// recipient nor change: it is set aside before attributing and stays inside
/// the reported fee (inputs minus what reached the recipient and us). When
/// this wallet authored the block, that share is a receipt of ours, which
/// [buildWormholeHistory] keeps visible.
_Batch _batch(WormholeSpend spend, List<WormholeUtxo> inputs, Set<String> ownAddresses) {
  final inputsToken = inputs.fold(BigInt.zero, (sum, u) => sum + u.amount);
  final feeShare = feeShareOf(spend);
  final exits = spend.outputs.where((o) => !identical(o, feeShare)).toList();
  final changeExits = exits.where((o) => ownAddresses.contains(o.exitAccountId)).toList();
  final change = changeExits.fold(BigInt.zero, (sum, o) => sum + o.amount);
  final foreign = exits.where((o) => !ownAddresses.contains(o.exitAccountId)).toList();
  if (WormholeSpend.privateBatchCalls.contains(spend.call) &&
      foreign.length == 1 &&
      inputsToken - foreign.single.amount - change >= BigInt.zero) {
    final sent = foreign.single.amount;
    return _Batch(
      spend: spend,
      inputs: inputs,
      recipient: foreign.single.exitAccountId,
      sentToken: sent,
      changeToken: change,
      changeExitIds: {for (final o in changeExits) o.id},
      feeToken: inputsToken - sent - change,
    );
  }
  quantusPrint(
    '[WormholeHistory] Spend ${spend.extrinsicId} is not a single send of this wallet '
    '(${spend.call}, ${foreign.length} exits to other addresses, $inputsToken of inputs): '
    'reporting it without a recipient',
  );
  return _Batch(
    spend: spend,
    inputs: inputs,
    recipient: null,
    sentToken: inputsToken,
    changeToken: BigInt.zero,
    changeExitIds: const {},
    feeToken: BigInt.zero,
  );
}

/// Coin selection runs once per send and returns change only on its last
/// batch, so [next] continues the send of [previous] when it pays the same
/// recipient, [previous] returned no change, every input of [next] already
/// existed when [previous] was submitted, and they landed within
/// [wormholeSendMergeWindow]. The age test keeps a send-max (no change,
/// everything spent) apart from a later send funded by new receipts; the
/// window keeps apart repeated sends whose amounts happen to consume whole
/// batches exactly, common for a miner with thousands of equal leaves.
bool _continuesSend(_Batch previous, _Batch next) =>
    previous.attributed &&
    previous.recipient == next.recipient &&
    !previous.hasChange &&
    next.newestInput.compareTo(previous.spend.position) < 0 &&
    next.spend.timestamp.difference(previous.spend.timestamp) <= wormholeSendMergeWindow;

/// Rebuilds an encrypted account's activity from the indexer alone: one
/// outgoing row per send (a send of more than seven inputs is several proof
/// extrinsics, merged by [_continuesSend]) and one incoming row per transfer
/// to any of the account's addresses that is not the change of one of those
/// sends. Newest first, in chain order.
List<TransactionEvent> buildWormholeHistory({
  required String accountId,
  required Set<String> ownAddresses,
  required List<WormholeUtxo> received,
  required Map<String, WormholeSpend> spends,
}) {
  final spendByExtrinsic = <String, WormholeSpend>{};
  final inputsByExtrinsic = <String, List<WormholeUtxo>>{};
  for (final utxo in received) {
    final spend = spends[utxo.nullifierHex];
    if (spend == null) continue;
    spendByExtrinsic[spend.extrinsicId] = spend;
    inputsByExtrinsic.putIfAbsent(spend.extrinsicId, () => []).add(utxo);
  }
  final batches = spendByExtrinsic.values
      .map((spend) => _batch(spend, inputsByExtrinsic[spend.extrinsicId]!, ownAddresses))
      .sorted((a, b) => a.spend.position.compareTo(b.spend.position));
  final sends = <List<_Batch>>[];
  for (final batch in batches) {
    final current = sends.lastOrNull;
    if (current != null && _continuesSend(current.last, batch)) {
      current.add(batch);
    } else {
      sends.add([batch]);
    }
  }
  // An exit and the transfer it created share an id, so this names exactly
  // the change of our sends; anything else a send paid us — the block
  // author's fee share when we mined the block — stays a receipt.
  final changeTransferIds = {for (final batch in batches) ...batch.changeExitIds};

  // Exit and transfer ids are `<block>-<hash>-<event index>`, zero-padded, so
  // they place every row at its position on chain.
  final rows = <(String position, TransactionEvent event)>[
    for (final send in sends)
      (
        send.last.spend.position,
        WormholeTransferEvent(
          id: send.last.spend.extrinsicId,
          from: accountId,
          to: send.first.recipient ?? '',
          amount: send.fold(BigInt.zero, (sum, b) => sum + b.sentToken),
          fee: send.fold(BigInt.zero, (sum, b) => sum + b.feeToken),
          timestamp: send.last.spend.timestamp,
          extrinsicHash: send.last.spend.extrinsicId,
          blockNumber: send.last.spend.blockHeight,
          batches: [for (final batch in send) batch.detail],
        ),
      ),
    for (final WormholeUtxo(:transfer) in received)
      if (!changeTransferIds.contains(transfer.id))
        (
          transfer.id,
          transfer.viaWormhole
              ? WormholeTransferEvent(
                  id: transfer.id,
                  from: transfer.fromId,
                  to: accountId,
                  amount: transfer.amount,
                  fee: BigInt.zero,
                  timestamp: transfer.timestamp,
                  extrinsicHash: transfer.extrinsicId,
                  blockNumber: transfer.blockHeight,
                )
              : TransferEvent(
                  id: transfer.id,
                  from: transfer.fromId,
                  to: accountId,
                  amount: transfer.amount,
                  fee: BigInt.zero,
                  timestamp: transfer.timestamp,
                  extrinsicHash: transfer.extrinsicId.isEmpty ? null : transfer.extrinsicId,
                  blockNumber: transfer.blockHeight,
                  blockHash: null,
                ),
        ),
  ];
  return rows.sorted((a, b) => b.$1.compareTo(a.$1)).map((row) => row.$2).toList();
}
