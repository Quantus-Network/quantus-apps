import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/pending_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';

final paginationControllerProvider = StateNotifierProvider<UnifiedPaginationController, PaginationState>(
  (ref) => UnifiedPaginationController(ref),
);

// Combined provider that reacts to both pending and paginated data
final allTransactionsProvider = Provider<AsyncValue<CombinedTransactionsList>>((ref) {
  final pendingCancellationIds = ref.watch(pendingCancellationsProvider);
  final pending = ref.watch(pendingTransactionsProvider);
  final pagination = ref.watch(paginationControllerProvider);

  if (pagination.error != null) {
    return AsyncValue.error(pagination.error!, pagination.stackTrace!);
  }
  if (pagination.isFetching && pagination.items.isEmpty) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    CombinedTransactionsList(
      pendingCancellationIds: pendingCancellationIds,
      pendingTransactions: pending,
      reversibleTransfers: pagination.reversibleTransfers,
      otherTransfers: pagination.items,
    ),
  );
});
