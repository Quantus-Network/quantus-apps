import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/filtered_transactions_params.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

const _backgroundPollFilters = [TransactionFilter.all];

/// Returns the currently selected wallet account ID, if any.
String? activeAccountId(Ref ref) => ref.read(activeAccountProvider).value?.account.accountId;

/// Builds deduplicated single-account refresh targets for event-driven updates.
List<List<String>> accountRefreshTargets({required Set<String> affectedAccountIds, String? activeId}) {
  final targets = <String>{...affectedAccountIds};
  if (activeId != null) {
    targets.add(activeId);
  }

  return targets.map((id) => [id]).toList();
}

/// Account IDs whose cached history should be consulted during pending-tx reconciliation.
Set<String> reconciliationAccountIds({
  required String? activeId,
  required Iterable<PendingTransactionEvent> pendingTxs,
}) {
  final ids = <String>{};
  if (activeId != null) {
    ids.add(activeId);
  }

  for (final tx in pendingTxs) {
    ids.add(tx.from);
    ids.add(tx.to);
  }

  return ids;
}

/// Invalidates balance for the active account only.
void invalidateActiveAccountBalance(Ref ref) {
  final accountId = activeAccountId(ref);
  if (accountId == null) return;

  ref.invalidate(balanceProviderFamily(accountId));
}

/// Invalidates balance for the given account IDs.
void invalidateAccountBalances(Ref ref, Iterable<String> accountIds) {
  for (final accountId in accountIds) {
    ref.invalidate(balanceProviderFamily(accountId));
  }
}

Future<void> refreshAccountsPagination(
  Ref ref, {
  required List<String> accountIds,
  required Future<void> Function(UnifiedPaginationController notifier) action,
  Iterable<TransactionFilter> filters = _backgroundPollFilters,
  bool isAccountInactive = false,
}) async {
  if (accountIds.isEmpty) return;

  final cachedIds = AccountIdListCache.get(accountIds);

  for (final filter in filters) {
    final params = FilteredTransactionsParams(accountIds: cachedIds, filter: filter);
    if (isAccountInactive && !ref.exists(filteredPaginationControllerProviderFamily(params))) {
      continue;
    }

    final notifier = ref.read(filteredPaginationControllerProviderFamily(params).notifier);
    await action(notifier);
  }
}

/// Silently refreshes pagination for the active account (background poll scope).
Future<void> silentRefreshActiveAccount(Ref ref) async {
  final accountId = activeAccountId(ref);
  if (accountId == null) return;

  await refreshAccountsPagination(ref, accountIds: [accountId], action: (notifier) => notifier.silentRefresh());
}

/// Refreshes the active account when the user switches accounts.
Future<void> refreshActiveAccountOnSwitch(Ref ref) async {
  final accountId = activeAccountId(ref);
  if (accountId == null) return;

  final params = FilteredTransactionsParams(
    accountIds: AccountIdListCache.get([accountId]),
    filter: TransactionFilter.all,
  );

  final paginationState = ref.read(filteredPaginationControllerProviderFamily(params));
  final notifier = ref.read(filteredPaginationControllerProviderFamily(params).notifier);

  if (paginationState.hasLoadedChainData) {
    await notifier.silentRefresh();
  } else {
    await notifier.loadingRefresh();
  }

  invalidateActiveAccountBalance(ref);
}
