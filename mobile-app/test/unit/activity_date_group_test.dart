import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(tz_data.initializeTimeZones);

  group('calendarDaysBetween', () {
    test('counts the spring-forward day, which elapses in 23 hours, as one day', () {
      final la = tz.getLocation('America/Los_Angeles');
      final mar8 = tz.TZDateTime(la, 2026, 3, 8);
      final mar9 = tz.TZDateTime(la, 2026, 3, 9);
      final mar10 = tz.TZDateTime(la, 2026, 3, 10);

      expect(mar9.difference(mar8).inHours, 23);
      expect(calendarDaysBetween(mar8, mar9), 1);
      expect(calendarDaysBetween(mar8, mar10), 2);
    });

    test('counts the fall-back day, which elapses in 25 hours, as one day', () {
      final la = tz.getLocation('America/Los_Angeles');
      final nov1 = tz.TZDateTime(la, 2026, 11, 1);
      final nov2 = tz.TZDateTime(la, 2026, 11, 2);

      expect(nov2.difference(nov1).inHours, 25);
      expect(calendarDaysBetween(nov1, nov2), 1);
      expect(calendarDaysBetween(nov1, tz.TZDateTime(la, 2026, 11, 1, 23, 59)), 0);
    });
  });

  group('dateGroupLabel', () {
    test('labels the day before today Yesterday across spring forward', () {
      final label = dateGroupLabel(DateTime(2026, 3, 8, 23, 30), l10n, 'en', now: DateTime(2026, 3, 9, 10));
      expect(label, l10n.activityDateYesterday);
    });

    test('labels a transaction from the same local day Today', () {
      final label = dateGroupLabel(DateTime(2026, 3, 9, 1), l10n, 'en', now: DateTime(2026, 3, 9, 23, 30));
      expect(label, l10n.activityDateToday);
    });
  });
}
