import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Draws [marks], in [room] when given: that wide at most.
Future<void> _pump(WidgetTester tester, ApprovalMarks marks, {double? room}) async {
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(
          body: Center(
            child: room == null
                ? marks
                : SizedBox(
                    width: room,
                    child: Align(alignment: AlignmentDirectional.centerStart, child: marks),
                  ),
          ),
        ),
      ),
    ),
  );
}

const _colors = AppColorsV3.dark();

/// The circles drawn, each filled or not.
List<bool> _circles(WidgetTester tester) => [
  for (final box in tester.widgetList<Container>(
    find.descendant(of: find.byType(ApprovalMarks), matching: find.byType(Container)),
  ))
    if (box.decoration case BoxDecoration(shape: BoxShape.circle, :final color)) color == _colors.semanticSage,
];

double _barWidth(WidgetTester tester) => tester.getSize(find.byKey(ApprovalMarks.barKey)).width;

double _filledWidth(WidgetTester tester) => tester.getSize(find.byKey(ApprovalMarks.barFillKey)).width;

void main() {
  testWidgets('draws one circle for each approval needed, the first of them filled for those given', (tester) async {
    await _pump(tester, const ApprovalMarks(approved: 1, needed: 3));

    expect(_circles(tester), [true, false, false]);
    expect(find.byKey(ApprovalMarks.barKey), findsNothing);
  });

  testWidgets('draws circles up to ten approvals needed', (tester) async {
    await _pump(tester, const ApprovalMarks(approved: 0, needed: ApprovalMarks.mostCircles));

    expect(_circles(tester), List.filled(10, false));
    expect(find.byKey(ApprovalMarks.barKey), findsNothing);
  });

  testWidgets('more than ten are one bar, no wider however many are needed, filled by the share given', (tester) async {
    await _pump(tester, const ApprovalMarks(approved: 25, needed: 50));
    final width = _barWidth(tester);

    expect(_circles(tester), isEmpty);
    expect(_filledWidth(tester), moreOrLessEquals(width / 2, epsilon: 0.01));
    expect(
      (tester.widget<Container>(find.byKey(ApprovalMarks.barFillKey)).decoration! as BoxDecoration).color,
      _colors.semanticSage,
    );

    await _pump(tester, const ApprovalMarks(approved: 25, needed: 100));
    expect(_barWidth(tester), width);
    expect(_filledWidth(tester), moreOrLessEquals(width / 4, epsilon: 0.01));

    await _pump(tester, const ApprovalMarks(approved: 11, needed: 11));
    expect(_barWidth(tester), width);
    expect(_filledWidth(tester), width);
  });

  testWidgets('a bar with no approval is empty, and a single one of many can still be seen', (tester) async {
    await _pump(tester, const ApprovalMarks(approved: 0, needed: 100));
    expect(find.byKey(ApprovalMarks.barFillKey), findsNothing);

    await _pump(tester, const ApprovalMarks(approved: 1, needed: 100));
    final bar = tester.getSize(find.byKey(ApprovalMarks.barKey));
    // A hundredth of the bar would be a sliver: it is at least a dot.
    expect(_filledWidth(tester), bar.height);
  });

  group('in less room than they take', () {
    testWidgets('circles that fit stay circles', (tester) async {
      // Ten circles of 10 with 5 between them.
      await _pump(tester, const ApprovalMarks(approved: 3, needed: 10), room: 145);

      expect(_circles(tester), [...List.filled(3, true), ...List.filled(7, false)]);
      expect(find.byKey(ApprovalMarks.barKey), findsNothing);
    });

    testWidgets('circles that do not fit become the bar, as wide as the room, filled by the share given', (
      tester,
    ) async {
      await _pump(tester, const ApprovalMarks(approved: 3, needed: 10), room: 80);

      expect(_circles(tester), isEmpty);
      expect(_barWidth(tester), 80);
      expect(_filledWidth(tester), moreOrLessEquals(24, epsilon: 0.01));
    });

    testWidgets('the bar narrows to the room', (tester) async {
      await _pump(tester, const ApprovalMarks(approved: 25, needed: 50), room: 60);

      expect(_barWidth(tester), 60);
      expect(_filledWidth(tester), moreOrLessEquals(30, epsilon: 0.01));
    });

    testWidgets('below the least bar there are no marks: the count beside them says it alone', (tester) async {
      await _pump(tester, const ApprovalMarks(approved: 25, needed: 50), room: ApprovalMarks.leastBarWidth - 1);

      expect(_circles(tester), isEmpty);
      expect(find.byKey(ApprovalMarks.barKey), findsNothing);
      expect(tester.getSize(find.byType(ApprovalMarks)).width, 0);

      await _pump(tester, const ApprovalMarks(approved: 25, needed: 50), room: ApprovalMarks.leastBarWidth);
      expect(_barWidth(tester), ApprovalMarks.leastBarWidth);
    });
  });

  testWidgets('a screen reader passes over circles and bar alike: the count is said in words beside them', (
    tester,
  ) async {
    for (final marks in const [ApprovalMarks(approved: 1, needed: 3), ApprovalMarks(approved: 1, needed: 50)]) {
      await _pump(tester, marks);
      expect(find.descendant(of: find.byType(ApprovalMarks), matching: find.byType(ExcludeSemantics)), findsOneWidget);
    }
  });
}
