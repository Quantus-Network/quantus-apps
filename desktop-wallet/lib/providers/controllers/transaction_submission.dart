import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/history_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

final pendingTransactionTrackerProvider = Provider<PendingTransactionTracker>((ref) {
  final tracker = PendingTransactionTracker(history: ref.watch(chainHistoryServiceProvider));
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// Shows a just-broadcast transfer as pending until the indexer has it, then
/// moves it into history and refreshes the balance.
void trackSubmittedTransfer(
  WidgetRef ref, {
  required Account account,
  required String recipient,
  required BigInt amount,
  required BigInt fee,
  required String extrinsicHash,
  required int blockNumber,
}) {
  final pending = PendingTransactionEvent(
    tempId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
    from: account.accountId,
    to: recipient,
    amount: amount,
    timestamp: DateTime.now(),
    fee: fee,
    extrinsicHash: extrinsicHash,
    blockNumber: blockNumber,
    transactionState: TransactionState.pending,
  );
  final pendingTransactions = ref.read(pendingTransactionsProvider.notifier);
  pendingTransactions.add(pending);
  unawaited(
    ref.read(pendingTransactionTrackerProvider).track(pending).then((found) {
      if (found != null) historyControllerFor(ref.read, account.accountId).addTransactionToHistory(found);
      pendingTransactions.remove(pending.id);
      ref.invalidate(balanceProviderFamily(account.accountId));
    }),
  );
}
