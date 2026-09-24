import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:quantus_sdk/generated/bell/pallets/wormhole.dart' as wormhole_pallet;
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// The batches of one send are proved and submitted back to back, a couple of
/// minutes apart; batches further apart than this belong to different sends.
const Duration wormholeSendMergeWindow = Duration(minutes: 5);

/// Address the chain mints wormhole exits and mining rewards from.
final String wormholeMintingAddress = AddressExtension.ss58AddressFromBytes(
  Uint8List.fromList(wormhole_pallet.Constants().mintingAccount),
);

/// A transfer settled by a wormhole proof: an encrypted send, or a receipt paid
/// out of someone else's. The explorer shows these under `wormhole/<extrinsic>`.
class WormholeTransferEvent extends TransferEvent {
  WormholeTransferEvent({
    required super.id,
    required super.from,
    required super.to,
    required super.amount,
    required super.timestamp,
    required super.fee,
    required super.extrinsicHash,
    required super.blockNumber,
  }) : super(blockHash: null);

  /// True for a spend whose proof settled together with other transfers, so
  /// the indexer cannot say which exit was ours: [amount] is what our inputs
  /// contributed and [to] is empty.
  bool get recipientUnknown => to.isEmpty;
}

/// One proof extrinsic that consumed inputs of this wallet. [recipient] is
/// null when its exits cannot be attributed to this wallet.
class _Batch {
  final WormholeSpend spend;
  final String? recipient;
  final BigInt sentToken;
  final BigInt changeToken;
  final BigInt feeToken;

  /// Chain position of the newest input this batch consumed.
  final String newestInput;

  const _Batch({
    required this.spend,
    required this.recipient,
    required this.sentToken,
    required this.changeToken,
    required this.feeToken,
    required this.newestInput,
  });

  bool get attributed => recipient != null;

  bool get hasChange => changeToken > BigInt.zero;
}

/// A send of this wallet is a private batch — one client's proof, and only
/// the holder of our secrets can put our leaves in one — that exits to exactly
/// one address that is not our own, plus optional change: every exit then
/// came from our inputs, so the ones to our own addresses are change.
/// Anything else (a public batch bundling several clients' proofs, or an exit
/// larger than our inputs) is reported by the full amount our inputs
/// contributed, with no recipient; nothing in such a proof is taken for
/// change, so a payment to us inside it stays a receipt.
_Batch _batch(WormholeSpend spend, BigInt inputsToken, String newestInput, Set<String> ownAddresses) {
  final change = spend.outputs
      .where((o) => ownAddresses.contains(o.exitAccountId))
      .fold(BigInt.zero, (sum, o) => sum + o.amount);
  final foreign = spend.outputs.where((o) => !ownAddresses.contains(o.exitAccountId)).toList();
  if (WormholeSpend.privateBatchCalls.contains(spend.call) &&
      foreign.length == 1 &&
      inputsToken - foreign.single.amount - change >= BigInt.zero) {
    final sent = foreign.single.amount;
    return _Batch(
      spend: spend,
      recipient: foreign.single.exitAccountId,
      sentToken: sent,
      changeToken: change,
      feeToken: inputsToken - sent - change,
      newestInput: newestInput,
    );
  }
  quantusPrint(
    '[WormholeHistory] Spend ${spend.extrinsicId} is not a single send of this wallet '
    '(${spend.call}, ${foreign.length} exits to other addresses, $inputsToken of inputs): '
    'reporting it without a recipient',
  );
  return _Batch(
    spend: spend,
    recipient: null,
    sentToken: inputsToken,
    changeToken: BigInt.zero,
    feeToken: BigInt.zero,
    newestInput: newestInput,
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
  final inputsByExtrinsic = <String, BigInt>{};
  final newestInputByExtrinsic = <String, String>{};
  for (final WormholeUtxo(:transfer, :nullifierHex) in received) {
    final spend = spends[nullifierHex];
    if (spend == null) continue;
    spendByExtrinsic[spend.extrinsicId] = spend;
    inputsByExtrinsic.update(spend.extrinsicId, (sum) => sum + transfer.amount, ifAbsent: () => transfer.amount);
    newestInputByExtrinsic.update(
      spend.extrinsicId,
      (newest) => transfer.id.compareTo(newest) > 0 ? transfer.id : newest,
      ifAbsent: () => transfer.id,
    );
  }
  final batches = spendByExtrinsic.values
      .map((spend) {
        final id = spend.extrinsicId;
        return _batch(spend, inputsByExtrinsic[id]!, newestInputByExtrinsic[id]!, ownAddresses);
      })
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
  final changeExtrinsics = {
    for (final batch in batches)
      if (batch.attributed) batch.spend.extrinsicId,
  };

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
        ),
      ),
    for (final WormholeUtxo(:transfer) in received)
      if (!changeExtrinsics.contains(transfer.extrinsicId))
        (
          transfer.id,
          transfer.fromId == wormholeMintingAddress && transfer.extrinsicId.isNotEmpty
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
