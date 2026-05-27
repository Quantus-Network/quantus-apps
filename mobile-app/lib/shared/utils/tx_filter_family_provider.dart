import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/filtered_transactions_params.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

void updatePaginationFiltersFor(
  Reader read,
  List<String> targetIds,
  void Function(UnifiedPaginationController notifier, TransactionFilter filter) action, {
  Iterable<TransactionFilter> filters = TransactionFilter.values,
}) {
  final cachedIds = AccountIdListCache.get(targetIds);

  for (final filter in filters) {
    final notifier = read(
      filteredPaginationControllerProviderFamily(
        FilteredTransactionsParams(accountIds: cachedIds, filter: filter),
      ).notifier,
    );

    action(notifier, filter);
  }
}
