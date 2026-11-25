import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/account_activity_reconciliation.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

/// Appends the execution to the executor's activity. The proposals were read again
/// before it, by `rereadMultisigProposals`.
Future<void> reconcileIndexedExecution(Ref ref, MultisigAccount msig, MultisigProposalExecutedEvent indexed) async {
  await appendConfirmedEventToHistory(
    ref: ref,
    accountId: indexed.executorId,
    event: indexed,
    includeForFilter: (filter) => filter != TransactionFilter.receive,
    isDuplicate: (tx) => tx is MultisigProposalExecutedEvent && tx.isSameExecutionAs(indexed),
  );

  invalidateAccountBalances(ref, {indexed.executorId, msig.accountId});
}
