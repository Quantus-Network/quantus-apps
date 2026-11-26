import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/models/filtered_transactions_params.dart';
import 'package:wallet_core/models/pagination_state.dart';
import 'package:wallet_core/providers/account_id_list_cache.dart';
import 'package:wallet_core/providers/controllers/unified_pagination_controller.dart';
import 'package:wallet_core/providers/pending_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';

/// Family provider for filtered pagination controllers.
///
/// Keyed on [FilteredTransactionsParams] so each unique (accountIds, filter)
/// combination owns its own [UnifiedPaginationController] instance and
/// independently cached page data.
final filteredPaginationControllerProviderFamily =
    StateNotifierProvider.family<UnifiedPaginationController, PaginationState, FilteredTransactionsParams>(
      (ref, params) => UnifiedPaginationController(ref, accountIds: params.accountIds, filter: params.filter),
    );

/// Everything the wallet has pending, every account's: what is being sent,
/// the multisigs being created, the proposals being proposed, approved,
/// executed or cancelled, and the reversible transfers being cancelled.
final pendingActivityProvider = Provider<CombinedTransactionsList>((ref) {
  return CombinedTransactionsList(
    pendingCancellationIds: ref.watch(pendingCancellationsProvider),
    pendingTransactions: ref.watch(pendingTransactionsProvider),
    pendingMultisigCreations: ref.watch(pendingMultisigCreationsProvider),
    pendingMultisigProposals: ref.watch(pendingMultisigProposalsProvider),
    pendingMultisigApprovals: ref.watch(pendingMultisigApprovalsProvider),
    pendingMultisigExecutions: ref.watch(pendingMultisigExecutionsProvider),
    pendingMultisigCancellations: ref.watch(pendingMultisigCancellationsProvider),
    scheduledReversibleTransfers: const [],
    otherTransfers: const [],
  );
});

/// What of the wallet's [pending] activity belongs to [accountIds] under
/// [filter]: what they send or receive, the multisigs they create, the
/// proposals they propose, approve, execute or cancel (none of it when only what was
/// received is asked for); with the history's [scheduledReversibleTransfers]
/// and [otherTransfers] as they are.
CombinedTransactionsList combinedTransactionsOf(
  CombinedTransactionsList pending, {
  required List<String> accountIds,
  required TransactionFilter filter,
  required List<ReversibleTransferEvent> scheduledReversibleTransfers,
  required List<TransactionEvent> otherTransfers,
}) {
  final sends = filter != TransactionFilter.receive;
  return CombinedTransactionsList(
    pendingCancellationIds: pending.pendingCancellationIds,
    pendingTransactions: pending.pendingTransactions
        .where((tx) => sends && (accountIds.contains(tx.from) || accountIds.contains(tx.to)))
        .toList(),
    pendingMultisigCreations: pending.pendingMultisigCreations
        .where((tx) => sends && accountIds.contains(tx.creatorId))
        .toList(),
    pendingMultisigProposals: pending.pendingMultisigProposals
        .where((tx) => sends && accountIds.contains(tx.proposerId))
        .toList(),
    pendingMultisigApprovals: pending.pendingMultisigApprovals
        .where((tx) => sends && accountIds.contains(tx.approverId))
        .toList(),
    pendingMultisigExecutions: pending.pendingMultisigExecutions
        .where((tx) => sends && accountIds.contains(tx.executorId))
        .toList(),
    pendingMultisigCancellations: pending.pendingMultisigCancellations
        .where((tx) => sends && accountIds.contains(tx.proposerId))
        .toList(),
    scheduledReversibleTransfers: scheduledReversibleTransfers,
    otherTransfers: otherTransfers,
  );
}

/// Combined provider for filtered transactions.
final filteredTransactionsProviderFamily =
    Provider.family<AsyncValue<CombinedTransactionsList>, FilteredTransactionsParams>((ref, params) {
      final normalizedParams = FilteredTransactionsParams(
        accountIds: AccountIdListCache.get(params.accountIds),
        filter: params.filter,
      );

      final pending = ref.watch(pendingActivityProvider);
      final pagination = ref.watch(filteredPaginationControllerProviderFamily(normalizedParams));

      if (pagination.error != null && !pagination.hasLoadedChainData) {
        quantusPrint('FilteredTransactionsProvider: Error: ${pagination.error}');
        return AsyncValue.error(pagination.error!, pagination.stackTrace!);
      }
      if (pagination.error != null) {
        quantusPrint('FilteredTransactionsProvider: Load-more error: ${pagination.error}');
      }
      if (pagination.isLoading && !pagination.hasLoadedChainData) {
        return const AsyncValue.loading();
      }

      return AsyncValue.data(
        combinedTransactionsOf(
          pending,
          accountIds: params.accountIds,
          filter: normalizedParams.filter,
          scheduledReversibleTransfers: pagination.scheduledReversibleTransfers,
          otherTransfers: pagination.otherTransfers,
        ),
      );
    });
