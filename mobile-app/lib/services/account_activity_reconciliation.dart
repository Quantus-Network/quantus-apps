import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/filtered_transactions_params.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/tx_filter_family_provider.dart';

/// Appends a confirmed activity event to cached history for [accountId].
Future<void> appendConfirmedEventToHistory({
  required Ref ref,
  required String accountId,
  required TransactionEvent event,
  required bool Function(TransactionFilter filter) includeForFilter,
  required bool Function(TransactionEvent existing) isDuplicate,
}) async {
  try {
    await refreshAccountsPagination(ref, accountIds: [accountId], action: (notifier) => notifier.silentRefresh());

    updatePaginationFiltersFor(ref.read, [accountId], (notifier, filter) {
      if (!includeForFilter(filter)) return;

      final params = FilteredTransactionsParams(accountIds: AccountIdListCache.get([accountId]), filter: filter);
      final pagination = ref.read(filteredPaginationControllerProviderFamily(params));
      if (pagination.otherTransfers.any(isDuplicate)) return;

      notifier.addTransactionToHistory(event);
    });

    invalidateAccountBalances(ref, [accountId]);
  } catch (e, stackTrace) {
    quantusDebugPrint('[AccountActivityReconcile] Error: $e');
    quantusDebugPrint('Stack trace: $stackTrace');
    TelemetryService().sendError('account_activity_reconcile_failed', error: e, stackTrace: stackTrace);
  }
}
