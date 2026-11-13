import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/services/account_activity_reconciliation.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

/// Refreshes proposal state and appends the execution to the executor's activity.
Future<void> reconcileIndexedExecution(Ref ref, MultisigAccount msig, MultisigProposalExecutedEvent indexed) async {
  invalidateMultisigProposals(ref, msig);

  await appendConfirmedEventToHistory(
    ref: ref,
    accountId: indexed.executorId,
    event: indexed,
    includeForFilter: (filter) => filter != TransactionFilter.receive,
    isDuplicate: (tx) => tx is MultisigProposalExecutedEvent && tx.isSameExecutionAs(indexed),
  );

  invalidateAccountBalances(ref, {indexed.executorId, msig.accountId});
}
