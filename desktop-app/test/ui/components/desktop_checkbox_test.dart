import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Pumps a checkbox that ticks and unticks itself, or with [available]
/// false one that cannot be used. Returns the values it reported.
Future<List<bool>> _pump(WidgetTester tester, {bool available = true}) async {
  final reported = <bool>[];
  var value = false;
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DesktopCheckbox(
              value: value,
              label: 'Send everything',
              onChanged: available
                  ? (ticked) {
                      reported.add(ticked);
                      setState(() => value = ticked);
                    }
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
  return reported;
}

bool _isTicked(WidgetTester tester) => tester.widget<Checkbox>(find.byType(Checkbox)).value!;

void _testOnDesktop(String description, WidgetTesterCallback body) {
  testWidgets(description, body, variant: TargetPlatformVariant.desktop());
}

void main() {
  _testOnDesktop('a click on the box ticks it, and another unticks it', (tester) async {
    final reported = await _pump(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(_isTicked(tester), isTrue);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(_isTicked(tester), isFalse);
    expect(reported, [true, false]);
  });

  _testOnDesktop('a click on its label ticks it too', (tester) async {
    final reported = await _pump(tester);

    await tester.tap(find.text('Send everything'));
    await tester.pump();

    expect(_isTicked(tester), isTrue);
    expect(reported, [true]);
  });

  _testOnDesktop('Tab reaches it and Space ticks it', (tester) async {
    final reported = await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(reported, [true]);
  });

  _testOnDesktop('with nothing to report to it is dimmed, and neither a click nor the keyboard ticks it', (
    tester,
  ) async {
    final reported = await _pump(tester, available: false);

    final dimming = tester.widget<Opacity>(
      find.ancestor(of: find.byType(Checkbox), matching: find.byType(Opacity)).first,
    );
    expect(dimming.opacity, 0.4);

    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    await tester.tap(find.text('Send everything'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(_isTicked(tester), isFalse);
    expect(reported, isEmpty);
  });

  _testOnDesktop('the box stands in the middle of the room it is said to take', (tester) async {
    await _pump(tester);

    final room = tester.getRect(find.byType(Checkbox));
    expect(room.size, const Size.square(DesktopCheckbox.boxExtent));
    expect(DesktopCheckbox.boxInset, (room.width - Checkbox.width) / 2);
  });

  _testOnDesktop('a usable one is not dimmed', (tester) async {
    await _pump(tester);

    final dimming = tester.widget<Opacity>(
      find.ancestor(of: find.byType(Checkbox), matching: find.byType(Opacity)).first,
    );
    expect(dimming.opacity, 1);
  });
}
