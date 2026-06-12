import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/filtered_transactions_params.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/pending_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Family provider for filtered pagination controllers.
///
/// Keyed on [FilteredTransactionsParams] so each unique (accountIds, filter)
/// combination owns its own [UnifiedPaginationController] instance and
/// independently cached page data.
final filteredPaginationControllerProviderFamily =
    StateNotifierProvider.family<UnifiedPaginationController, PaginationState, FilteredTransactionsParams>(
      (ref, params) => UnifiedPaginationController(ref, accountIds: params.accountIds, filter: params.filter),
    );

/// Combined provider for filtered transactions.
final filteredTransactionsProviderFamily =
    Provider.family<AsyncValue<CombinedTransactionsList>, FilteredTransactionsParams>((ref, params) {
      final normalizedParams = FilteredTransactionsParams(
        accountIds: AccountIdListCache.get(params.accountIds),
        filter: params.filter,
      );

      final pendingCancellationIds = ref.watch(pendingCancellationsProvider);
      final pending = ref.watch(pendingTransactionsProvider);
      final pendingMultisigCreations = ref.watch(pendingMultisigCreationsProvider);
      final pendingMultisigProposals = ref.watch(pendingMultisigProposalsProvider);
      final pendingMultisigExecutions = ref.watch(pendingMultisigExecutionsProvider);
      final pendingMultisigCancellations = ref.watch(pendingMultisigCancellationsProvider);
      final pagination = ref.watch(filteredPaginationControllerProviderFamily(normalizedParams));

      if (pagination.error != null && !pagination.hasLoadedChainData) {
        quantusDebugPrint('FilteredTransactionsProvider: Error: ${pagination.error}');
        return AsyncValue.error(pagination.error!, pagination.stackTrace!);
      }
      if (pagination.error != null) {
        quantusDebugPrint('FilteredTransactionsProvider: Load-more error: ${pagination.error}');
      }
      if (pagination.isLoading && !pagination.hasLoadedChainData) {
        return const AsyncValue.loading();
      }

      final accountIds = params.accountIds;
      final filteredPending = pending
          .where(
            (tx) =>
                normalizedParams.filter != TransactionFilter.receive &&
                (accountIds.contains(tx.from) || accountIds.contains(tx.to)),
          )
          .toList();
      final filteredPendingMultisig = pendingMultisigCreations
          .where((tx) => normalizedParams.filter != TransactionFilter.receive && accountIds.contains(tx.creatorId))
          .toList();
      final filteredPendingProposals = pendingMultisigProposals
          .where((tx) => normalizedParams.filter != TransactionFilter.receive && accountIds.contains(tx.proposerId))
          .toList();
      final filteredPendingExecutions = pendingMultisigExecutions
          .where((tx) => normalizedParams.filter != TransactionFilter.receive && accountIds.contains(tx.executorId))
          .toList();
      final filteredPendingCancellations = pendingMultisigCancellations
          .where((tx) => normalizedParams.filter != TransactionFilter.receive && accountIds.contains(tx.proposerId))
          .toList();

      return AsyncValue.data(
        CombinedTransactionsList(
          pendingCancellationIds: pendingCancellationIds,
          pendingTransactions: filteredPending,
          pendingMultisigCreations: filteredPendingMultisig,
          pendingMultisigProposals: filteredPendingProposals,
          pendingMultisigExecutions: filteredPendingExecutions,
          pendingMultisigCancellations: filteredPendingCancellations,
          scheduledReversibleTransfers: pagination.scheduledReversibleTransfers,
          otherTransfers: pagination.otherTransfers,
        ),
      );
    });
