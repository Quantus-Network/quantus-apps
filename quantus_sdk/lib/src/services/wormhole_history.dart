import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:quantus_sdk/generated/bell/pallets/wormhole.dart' as wormhole_pallet;
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// The batches of one send are proved and submitted back to back; spends to
/// the same recipient further apart than this are separate sends.
const Duration wormholeSendMergeWindow = Duration(minutes: 30);

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
  /// the indexer cannot say which exit was ours: [amount] is what left the
  /// account and [to] is empty.
  bool get recipientUnknown => to.isEmpty;
}

/// One proof extrinsic that consumed inputs of this wallet: how its exits
/// split between the recipient and the wallet's own change. [recipient] is
/// null when the exits cannot be attributed.
class _Batch {
  final WormholeSpend spend;
  final String? recipient;
  final BigInt sentToken;
  final BigInt changeToken;
  final BigInt feeToken;

  const _Batch({
    required this.spend,
    required this.recipient,
    required this.sentToken,
    required this.changeToken,
    required this.feeToken,
  });

  bool get hasChange => changeToken > BigInt.zero;
}

/// A send of this wallet exits to exactly one address that is not its own,
/// plus optional change; anything else (an aggregated proof carrying other
/// users' inputs and exits, or an exit larger than our inputs) is reported by
/// the amount our inputs contributed, with no recipient.
_Batch _batch(WormholeSpend spend, BigInt inputsToken, Set<String> ownAddresses) {
  final change = spend.outputs
      .where((o) => ownAddresses.contains(o.exitAccountId))
      .fold(BigInt.zero, (sum, o) => sum + o.amount);
  final foreign = spend.outputs.where((o) => !ownAddresses.contains(o.exitAccountId)).toList();
  if (foreign.length == 1 && inputsToken - foreign.single.amount - change >= BigInt.zero) {
    final sent = foreign.single.amount;
    return _Batch(
      spend: spend,
      recipient: foreign.single.exitAccountId,
      sentToken: sent,
      changeToken: change,
      feeToken: inputsToken - sent - change,
    );
  }
  quantusPrint(
    '[WormholeHistory] Spend ${spend.extrinsicId} is not a single send of this wallet '
    '(${foreign.length} exits to other addresses, $inputsToken of inputs): reporting it without a recipient',
  );
  return _Batch(
    spend: spend,
    recipient: null,
    sentToken: inputsToken - change,
    changeToken: change,
    feeToken: BigInt.zero,
  );
}

/// Coin selection puts change only on a send's last batch, so a batch without
/// change followed closely by one to the same recipient is the same send.
bool _continuesSend(_Batch previous, _Batch next) =>
    previous.recipient != null &&
    previous.recipient == next.recipient &&
    !previous.hasChange &&
    next.spend.timestamp.difference(previous.spend.timestamp) <= wormholeSendMergeWindow;

/// Rebuilds an encrypted account's activity from the indexer alone: one
/// outgoing row per send (its batches merged, change hidden) and one incoming
/// row per transfer to any of the account's addresses that is not its own
/// change. Newest first.
List<TransactionEvent> buildWormholeHistory({
  required String accountId,
  required Set<String> ownAddresses,
  required List<WormholeUtxo> received,
  required Map<String, WormholeSpend> spends,
}) {
  final spendByExtrinsic = <String, WormholeSpend>{};
  final inputsByExtrinsic = <String, BigInt>{};
  for (final utxo in received) {
    final spend = spends[utxo.nullifierHex];
    if (spend == null) continue;
    spendByExtrinsic[spend.extrinsicId] = spend;
    inputsByExtrinsic.update(spend.extrinsicId, (sum) => sum + utxo.amount, ifAbsent: () => utxo.amount);
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

  final events = <TransactionEvent>[
    for (final send in sends)
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
    for (final WormholeUtxo(:transfer) in received)
      if (!spendByExtrinsic.containsKey(transfer.extrinsicId))
        if (transfer.fromId == wormholeMintingAddress && transfer.extrinsicId.isNotEmpty)
          WormholeTransferEvent(
            id: transfer.id,
            from: transfer.fromId,
            to: accountId,
            amount: transfer.amount,
            fee: BigInt.zero,
            timestamp: transfer.timestamp,
            extrinsicHash: transfer.extrinsicId,
            blockNumber: transfer.blockHeight,
          )
        else
          TransferEvent(
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
  ];
  return events.sorted((a, b) {
    final byTime = b.timestamp.compareTo(a.timestamp);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
}
