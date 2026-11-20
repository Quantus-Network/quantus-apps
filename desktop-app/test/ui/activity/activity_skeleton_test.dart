import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_skeleton.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

/// Short: the test's font draws every letter as wide as it is tall, so a
/// whole address would wrap here, where in the app's monospaced face it
/// takes one line, as the skeleton draws it.
const _bob = 'qzBob';

/// A first load's skeleton at [width] by 600, and under it a real row with
/// an address at the same width, each laid out as the Activity panel lays
/// out its list: 8 in from the panel's sides.
Future<void> _pumpBoth(WidgetTester tester, double width) async {
  useFakeCheckphrases(fakeCheckphrase);
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
          home: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 600, child: ActivitySkeleton()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ActivityRowView(
                      id: 'tx',
                      row: ActivityRow(
                        label: 'Sent',
                        timeLabel: '1d ago',
                        highlight: ActivityHighlight.none,
                        icon: ActivityIcon.direction,
                        isSend: true,
                        amount: oneToken,
                        hidesAmount: false,
                        counterparty: const ActivityAccount(_bob, isRecipient: true),
                        movedNothing: false,
                      ),
                      amountText: '1 QTC',
                      form: ActivityRowForm.of(width - 16),
                      l10n: _l10n,
                      isSelected: false,
                      hasFocus: true,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group("the days a first load's skeleton lays out", () {
    const row = 56.0;
    const firstHeading = 35.0;
    const heading = 41.0;

    for (final height in [400.0, 640.0, 900.0]) {
      test('in $height: more than one day, not all the same size, filling it to within one row', () {
        final days = ActivitySkeleton.daysFor(
          height: height,
          rowHeight: row,
          firstHeadingHeight: firstHeading,
          headingHeight: heading,
        );
        final used = firstHeading + heading * (days.length - 1) + row * days.fold(0, (sum, rows) => sum + rows);

        expect(days.length, greaterThan(1));
        expect(days.toSet().length, greaterThan(1));
        expect(days, everyElement(greaterThan(0)), reason: 'no heading without a row under it');
        expect(used, lessThanOrEqualTo(height));
        expect(used, greaterThan(height - row));
      });
    }

    test('with no room for a heading and a row, none', () {
      expect(
        ActivitySkeleton.daysFor(height: 80, rowHeight: row, firstHeadingHeight: firstHeading, headingHeight: heading),
        isEmpty,
      );
    });
  });

  group('its rows are shaped as a real row with an address is, at the same width', () {
    for (final (form, width) in [('wide', 800.0), ('tight', 600.0), ('brief', 400.0)]) {
      testWidgets('$form: as tall, and the address where the real one is', (tester) async {
        await _pumpBoth(tester, width);

        final ghost = tester.getRect(find.byKey(ActivitySkeleton.rowKey(0)));
        final real = tester.getRect(find.byType(ActivityRowView));
        expect(ghost.height, moreOrLessEquals(real.height, epsilon: 0.5));
        expect(ghost.left, moreOrLessEquals(real.left, epsilon: 0.5));

        final realWho = find.byType(DesktopAddressCheckphrase);
        if (form == 'brief') {
          expect(realWho, findsNothing);
          expect(find.byKey(ActivitySkeleton.whoKey(0)), findsNothing);
        } else {
          final who = tester.getRect(find.byKey(ActivitySkeleton.whoKey(0)));
          expect(who.left - ghost.left, moreOrLessEquals(tester.getRect(realWho).left - real.left, epsilon: 0.5));
          expect(who.top - ghost.top, moreOrLessEquals(tester.getRect(realWho).top - real.top, epsilon: 0.5));
          expect(who.height, moreOrLessEquals(tester.getRect(realWho).height, epsilon: 0.5));
        }
      });
    }
  });
}
