import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:quantus_sdk/generated/bell/pallets/wormhole.dart' as wormhole_pallet;
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

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
  final BigInt feeToken;

  const _Batch({required this.spend, required this.recipient, required this.sentToken, required this.feeToken});

  bool get attributed => recipient != null;
}

/// A send of this wallet is a proof that consumed only this wallet's inputs
/// ([ownNullifiers] of them) and exits to exactly one address that is not its
/// own, plus optional change — every exit then came from our inputs, so the
/// ones to our own addresses are change. Anything else (a proof that also
/// carried other users' inputs, or an exit larger than our inputs) is
/// reported by the full amount our inputs contributed, with no recipient;
/// nothing in such a proof is taken for change, so a payment to us inside it
/// stays a receipt.
_Batch _batch(WormholeSpend spend, int ownNullifiers, BigInt inputsToken, Set<String> ownAddresses) {
  final change = spend.outputs
      .where((o) => ownAddresses.contains(o.exitAccountId))
      .fold(BigInt.zero, (sum, o) => sum + o.amount);
  final foreign = spend.outputs.where((o) => !ownAddresses.contains(o.exitAccountId)).toList();
  if (spend.nullifierCount == ownNullifiers &&
      foreign.length == 1 &&
      inputsToken - foreign.single.amount - change >= BigInt.zero) {
    final sent = foreign.single.amount;
    return _Batch(
      spend: spend,
      recipient: foreign.single.exitAccountId,
      sentToken: sent,
      feeToken: inputsToken - sent - change,
    );
  }
  quantusPrint(
    '[WormholeHistory] Spend ${spend.extrinsicId} is not a single send of this wallet '
    '($ownNullifiers of ${spend.nullifierCount} inputs ours, ${foreign.length} exits to other addresses, '
    '$inputsToken of inputs): reporting it without a recipient',
  );
  return _Batch(spend: spend, recipient: null, sentToken: inputsToken, feeToken: BigInt.zero);
}

/// Rebuilds an encrypted account's activity from the indexer alone: one
/// outgoing row per proof extrinsic that consumed the account's inputs (a send
/// of more than seven inputs is several extrinsics and shows as several rows —
/// nothing on chain ties them together) and one incoming row per transfer to
/// any of the account's addresses that is not the change of one of those
/// sends. Newest first, in chain order.
List<TransactionEvent> buildWormholeHistory({
  required String accountId,
  required Set<String> ownAddresses,
  required List<WormholeUtxo> received,
  required Map<String, WormholeSpend> spends,
}) {
  final spendByExtrinsic = <String, WormholeSpend>{};
  final inputsByExtrinsic = <String, BigInt>{};
  final ownNullifiersByExtrinsic = <String, int>{};
  for (final utxo in received) {
    final spend = spends[utxo.nullifierHex];
    if (spend == null) continue;
    spendByExtrinsic[spend.extrinsicId] = spend;
    inputsByExtrinsic.update(spend.extrinsicId, (sum) => sum + utxo.amount, ifAbsent: () => utxo.amount);
    ownNullifiersByExtrinsic.update(spend.extrinsicId, (n) => n + 1, ifAbsent: () => 1);
  }
  final batches = [
    for (final MapEntry(key: id, value: spend) in spendByExtrinsic.entries)
      _batch(spend, ownNullifiersByExtrinsic[id]!, inputsByExtrinsic[id]!, ownAddresses),
  ];
  final changeExtrinsics = {
    for (final batch in batches)
      if (batch.attributed) batch.spend.extrinsicId,
  };

  // Exit and transfer ids are `<block>-<hash>-<event index>`, zero-padded, so
  // they place every row at its position on chain.
  final rows = <(String position, TransactionEvent event)>[
    for (final batch in batches)
      (
        batch.spend.position,
        WormholeTransferEvent(
          id: batch.spend.extrinsicId,
          from: accountId,
          to: batch.recipient ?? '',
          amount: batch.sentToken,
          fee: batch.feeToken,
          timestamp: batch.spend.timestamp,
          extrinsicHash: batch.spend.extrinsicId,
          blockNumber: batch.spend.blockHeight,
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
