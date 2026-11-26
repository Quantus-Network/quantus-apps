import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/account_activity_reconciliation.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

/// Appends the cancellation to the proposer's activity. The proposals were read again
/// before it, by `rereadMultisigProposals`.
Future<void> reconcileIndexedCancellation(Ref ref, MultisigAccount msig, MultisigProposalCancelledEvent indexed) async {
  await appendConfirmedEventToHistory(
    ref: ref,
    accountId: indexed.proposerId,
    event: indexed,
    includeForFilter: (filter) => filter != TransactionFilter.receive,
    isDuplicate: (tx) => tx is MultisigProposalCancelledEvent && tx.isSameCancellationAs(indexed),
  );

  invalidateAccountBalances(ref, {indexed.proposerId, msig.accountId});
}
