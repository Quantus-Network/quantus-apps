import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// Indexed history of the current account plus its pending transactions.
class AccountHistory {
  final List<PendingTransactionEvent> pending;
  final List<TransactionEvent> events;
  final bool hasMore;
  final bool isLoading;
  final bool isFetching;
  final Object? error;

  const AccountHistory({
    required this.pending,
    required this.events,
    required this.hasMore,
    required this.isLoading,
    required this.isFetching,
    this.error,
  });

  bool get isEmpty => pending.isEmpty && events.isEmpty;
}

FilteredTransactionsParams historyParamsFor(String accountId) =>
    FilteredTransactionsParams(accountIds: AccountIdListCache.get([accountId]), filter: TransactionFilter.all);

final accountHistoryProvider = Provider<AccountHistory?>((ref) {
  final account = ref.watch(currentAccountProvider);
  if (account == null) return null;
  final pagination = ref.watch(filteredPaginationControllerProviderFamily(historyParamsFor(account.accountId)));
  final pending = ref
      .watch(pendingTransactionsProvider)
      .where((tx) => tx.from == account.accountId || tx.to == account.accountId)
      .toList();
  final events = [...pagination.scheduledReversibleTransfers, ...pagination.otherTransfers]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return AccountHistory(
    pending: pending,
    events: events,
    hasMore: pagination.hasMore,
    isLoading: pagination.isLoading && !pagination.hasLoadedChainData,
    isFetching: pagination.isFetching,
    error: pagination.error,
  );
});

UnifiedPaginationController historyControllerFor(ProviderReader read, String accountId) =>
    read(filteredPaginationControllerProviderFamily(historyParamsFor(accountId)).notifier);
