import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_switch.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Pumps a switch that follows itself, or with [available] false one that
/// cannot be used. Returns the values it reported.
Future<List<bool>> _pump(WidgetTester tester, {bool available = true, bool initial = false}) async {
  final reported = <bool>[];
  var value = initial;
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => DesktopSwitch(
                value: value,
                label: 'Team',
                onChanged: available
                    ? (on) {
                        reported.add(on);
                        setState(() => value = on);
                      }
                    : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return reported;
}

void _testOnDesktop(String description, WidgetTesterCallback body) {
  testWidgets(description, body, variant: TargetPlatformVariant.desktop());
}

void main() {
  _testOnDesktop('a click turns it on, and another turns it off', (tester) async {
    final reported = await _pump(tester);

    await tester.tap(find.byType(DesktopSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DesktopSwitch));
    await tester.pumpAndSettle();

    expect(reported, [true, false]);
  });

  _testOnDesktop('Tab reaches it and Space toggles it', (tester) async {
    final reported = await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(reported, [true]);
  });

  _testOnDesktop('a screen reader hears its name and state', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, initial: true);

    expect(
      tester.getSemantics(find.descendant(of: find.byType(DesktopSwitch), matching: find.byType(CupertinoSwitch))),
      isSemantics(label: 'Team', hasToggledState: true, isToggled: true, hasEnabledState: true, isEnabled: true),
    );
    semantics.dispose();
  });

  _testOnDesktop('with no action it is dimmed and does nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    final reported = await _pump(tester, available: false);

    await tester.tap(find.byType(DesktopSwitch), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(reported, isEmpty);
    expect(
      tester.widget<Opacity>(find.descendant(of: find.byType(DesktopSwitch), matching: find.byType(Opacity))).opacity,
      0.5,
    );
    expect(
      tester.getSemantics(find.descendant(of: find.byType(DesktopSwitch), matching: find.byType(CupertinoSwitch))),
      isSemantics(label: 'Team', hasToggledState: true, isToggled: false, hasEnabledState: true, isEnabled: false),
    );
    semantics.dispose();
  });

  _testOnDesktop('it shows an arrow, as a macOS control does', (tester) async {
    await _pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    await mouse.addPointer(location: tester.getCenter(find.byType(DesktopSwitch)));
    await tester.pump();

    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
  });
}
