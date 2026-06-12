import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/account_activity_reconciliation.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Appends a confirmed multisig creation to cached activity history.
Future<void> reconcileConfirmedMultisigCreation(Ref ref, MultisigAccount draft, {required BigInt networkFee}) async {
  final created = await _loadCreatedEvent(ref, draft, networkFee: networkFee);
  final creatorId = draft.creator ?? draft.myMemberAccountId;
  final affectedIds = {...draft.signers, creatorId};

  try {
    await appendConfirmedEventToHistory(
      ref: ref,
      accountId: creatorId,
      event: created,
      includeForFilter: (filter) =>
          _showsMultisigCreationForFilter(filter: filter, accountId: creatorId, creatorId: creatorId),
      isDuplicate: (tx) => tx is MultisigCreatedEvent && tx.multisigAddress == created.multisigAddress,
    );

    invalidateAccountBalances(ref, affectedIds);
  } catch (e, stackTrace) {
    quantusDebugPrint('[MultisigCreationReconcile] Error: $e');
    quantusDebugPrint('Stack trace: $stackTrace');
  }
}

Future<MultisigCreatedEvent> _loadCreatedEvent(Ref ref, MultisigAccount draft, {required BigInt networkFee}) async {
  try {
    final record = await ref.read(multisigServiceProvider).fetchMultisigFromIndexer(draft.accountId);
    if (record != null) {
      return MultisigCreatedEvent.fromMultisigGraphql(multisig: record);
    }
  } catch (e, stackTrace) {
    quantusDebugPrint('[MultisigCreationReconcile] Indexer unavailable ($e); using draft with preflight networkFee');
    quantusDebugPrint('Stack trace: $stackTrace');
  }

  return MultisigCreatedEvent.fromDraft(draft, networkFee: networkFee);
}

bool _showsMultisigCreationForFilter({
  required TransactionFilter filter,
  required String accountId,
  required String creatorId,
}) {
  return switch (filter) {
    TransactionFilter.receive => false,
    TransactionFilter.all || TransactionFilter.send => accountId == creatorId,
  };
}
