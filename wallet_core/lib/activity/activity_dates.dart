import 'package:clock/clock.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// One day of an account's activity: its [label], then what was done on it.
class ActivityDay {
  const ActivityDay({required this.label, required this.transactions});

  /// "Today", "Yesterday", or the date. Each app chooses its case.
  final String label;

  final List<TransactionEvent> transactions;
}

/// [transactions] grouped by the day they were made, in the order given:
/// each day where its first transaction is, and its transactions in their
/// order.
List<ActivityDay> activityDaysOf(
  List<TransactionEvent> transactions,
  AppLocalizations l10n,
  String localeName, {
  DateTime? now,
}) {
  final days = <DateTime, ActivityDay>{};
  for (final tx in transactions) {
    final local = tx.timestamp.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    days
        .putIfAbsent(
          day,
          () => ActivityDay(
            label: dateGroupLabel(tx.timestamp, l10n, localeName, now: now),
            transactions: [],
          ),
        )
        .transactions
        .add(tx);
  }
  return days.values.toList();
}

/// Calendar days from [from] to [to], comparing date components only. Normalizing
/// through UTC keeps daylight-saving days, which elapse in 23 or 25 hours, one day apart.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// "Today", "Yesterday", or [date] in [localeName]'s way, by the day the
/// person saw it rather than the UTC day.
String dateGroupLabel(DateTime date, AppLocalizations l10n, String localeName, {DateTime? now}) {
  // Indexer timestamps are UTC; group by the day the user saw, not the UTC day.
  final diff = calendarDaysBetween(date.toLocal(), (now ?? clock.now()).toLocal());
  if (diff == 0) return l10n.activityDateToday;
  if (diff == 1) return l10n.activityDateYesterday;
  return DatetimeFormattingService.formatDateGroupLabel(date, localeName);
}
