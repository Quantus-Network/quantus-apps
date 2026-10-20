import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/balance_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

final chartRangeProvider = StateProvider<BalanceHistoryRange>((_) => BalanceHistoryRange.month);

/// Pages of history to walk back through at most; "All" may stop early.
const chartHistoryPageCap = 10;

/// Balance over time for the current account, reconstructed from history.
final balanceChartProvider = FutureProvider<List<BalanceHistoryPoint>>((ref) async {
  final account = ref.watch(currentAccountProvider);
  final balance = ref.watch(currentBalanceProvider).value;
  if (account == null || balance == null) return const [];
  final range = ref.watch(chartRangeProvider);
  final now = DateTime.now();
  final span = range.span;
  final start = span == null ? null : now.subtract(span);
  final history = ref.read(chainHistoryServiceProvider);
  final events = <TransactionEvent>[];
  AccountEventCursor? other;
  AccountEventCursor? scheduled;
  for (var page = 0; page < chartHistoryPageCap; page++) {
    final result = await history.fetchAllTransactionTypes(
      accountIds: [account.accountId],
      limit: 50,
      otherAfter: other,
      scheduledAfter: scheduled,
      filter: TransactionFilter.all,
    );
    events.addAll(result.otherTransfers);
    events.addAll(result.scheduledReversibleTransfers);
    other = result.nextOtherCursor;
    scheduled = result.nextScheduledCursor;
    final oldest = events.isEmpty ? null : events.map((e) => e.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
    if (!result.hasMore || (start != null && oldest != null && oldest.isBefore(start))) break;
  }
  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return BalanceHistory.derive(
    accountId: account.accountId,
    currentBalance: balance,
    newestFirst: events,
    range: range,
    now: now,
  );
});
