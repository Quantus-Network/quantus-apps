import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/pending_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final paginationControllerProvider = StateNotifierProvider<UnifiedPaginationController, PaginationState>(
  (ref) => UnifiedPaginationController(ref),
);

// Combined provider that reacts to both pending and paginated data
final allTransactionsProvider = Provider<AsyncValue<CombinedTransactionsList>>((ref) {
  final pendingCancellationIds = ref.watch(pendingCancellationsProvider);
  final pending = ref.watch(pendingTransactionsProvider);
  final pendingMultisigCreations = ref.watch(pendingMultisigCreationsProvider);
  final pendingMultisigProposals = ref.watch(pendingMultisigProposalsProvider);
  final pendingMultisigExecutions = ref.watch(pendingMultisigExecutionsProvider);
  final pendingMultisigCancellations = ref.watch(pendingMultisigCancellationsProvider);
  final pagination = ref.watch(paginationControllerProvider);

  if (pagination.error != null && !pagination.hasLoadedChainData) {
    quantusDebugPrint('AllTransactionsProvider: Error: ${pagination.error}');
    return AsyncValue.error(pagination.error!, pagination.stackTrace!);
  }
  if (pagination.error != null) {
    quantusDebugPrint('AllTransactionsProvider: Load-more error: ${pagination.error}');
  }
  if (pagination.isLoading && !pagination.hasLoadedChainData) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    CombinedTransactionsList(
      pendingCancellationIds: pendingCancellationIds,
      pendingTransactions: pending,
      pendingMultisigCreations: pendingMultisigCreations,
      pendingMultisigProposals: pendingMultisigProposals,
      pendingMultisigExecutions: pendingMultisigExecutions,
      pendingMultisigCancellations: pendingMultisigCancellations,
      scheduledReversibleTransfers: pagination.scheduledReversibleTransfers,
      otherTransfers: pagination.otherTransfers,
    ),
  );
});
