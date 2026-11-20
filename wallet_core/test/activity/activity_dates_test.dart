import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_dates.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 3, 9, 10);

  setUpAll(() => initializeDateFormatting('en'));

  TransferEvent at(DateTime time, String id) => TransferEvent(
    id: id,
    from: 'qzfrom',
    to: 'qzto',
    amount: BigInt.one,
    timestamp: time,
    fee: BigInt.zero,
    blockNumber: 1,
    blockHash: '0xblock',
  );

  group('a day\'s label', () {
    test('is Today, then Yesterday, then the date', () {
      expect(dateGroupLabel(DateTime(2026, 3, 9, 1), l10n, 'en', now: now), l10n.activityDateToday);
      expect(dateGroupLabel(DateTime(2026, 3, 8, 23, 30), l10n, 'en', now: now), l10n.activityDateYesterday);
      expect(dateGroupLabel(DateTime(2026, 3, 6, 12), l10n, 'en', now: now), 'Mar 6, 2026');
    });

    test('goes by the calendar, not by 24 hours', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 8, 23, 59), DateTime(2026, 3, 9, 0, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 3, 9, 0, 1), DateTime(2026, 3, 9, 23, 59)), 0);
    });
  });

  test('transactions are grouped by the day they were made, in the order given', () {
    final days = activityDaysOf(
      [
        at(DateTime(2026, 3, 9, 9), 'a'),
        at(DateTime(2026, 3, 9, 1), 'b'),
        at(DateTime(2026, 3, 8, 20), 'c'),
        at(DateTime(2026, 3, 6, 12), 'd'),
        at(DateTime(2026, 3, 6, 8), 'e'),
      ],
      l10n,
      'en',
      now: now,
    );

    // Lists, not records: a list inside a record is compared by identity.
    expect(
      [
        for (final day in days) [day.label, ...day.transactions.map((tx) => tx.id)],
      ],
      [
        [l10n.activityDateToday, 'a', 'b'],
        [l10n.activityDateYesterday, 'c'],
        ['Mar 6, 2026', 'd', 'e'],
      ],
    );
  });

  test('no transactions make no days', () {
    expect(activityDaysOf(const [], l10n, 'en', now: now), isEmpty);
  });
}
