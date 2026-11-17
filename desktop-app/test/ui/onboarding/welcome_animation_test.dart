import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/import_wallet_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/wallet_created_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/wave_field.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/utils/ascii_field.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

// The window is 1200 x 800. The website sizes its grid from a cell of
// 6.82 x 13.42 points, which gives 175 columns and 59 rows.
const _cols = 175;
const _rows = 59;

String _drawn(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(WaveField), matching: find.byType(Text))).data!;

/// The field in wave mode [m],[n] once the app has run for [elapsed]. The
/// website advances its clock by 0.01 a frame: 0.6 a second.
String _field(int m, int n, [Duration elapsed = Duration.zero]) => renderAsciiField(
  m: m,
  n: n,
  t: elapsed.inMicroseconds / Duration.microsecondsPerSecond * 0.6,
  cols: _cols,
  rows: _rows,
);

/// Opens the app on Welcome with its background moving. A moving background
/// never settles, so the tests here pump by hand.
Future<void> _pumpWelcome(WidgetTester tester, {bool reduceMotion = false, FakeWalletDevice? device}) async {
  await pumpShell(
    tester,
    overrides: (device ?? FakeWalletDevice()).overrides,
    settle: false,
    reduceMotion: reduceMotion,
  );
  await tester.pump();
  expect(find.byType(WelcomePage), findsOneWidget);
}

Future<TestGesture> _mouseAt(WidgetTester tester, Offset position) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(position);
  await tester.pump();
  return mouse;
}

void main() {
  testOnMac('Welcome draws the website\'s field across the whole window, behind its content', (tester) async {
    await _pumpWelcome(tester);

    expect(tester.getRect(find.byType(WaveField)), const Rect.fromLTWH(0, 0, 1200, 800));
    expect(_drawn(tester), _field(2, 2));
    expect(find.widgetWithText(QuantusButton, 'Create New Wallet'), findsOneWidget);
  });

  testOnMac('the field moves as time passes', (tester) async {
    await _pumpWelcome(tester);

    await tester.pump(const Duration(seconds: 5));

    expect(_drawn(tester), _field(2, 2, const Duration(seconds: 5)));
    expect(_drawn(tester), isNot(_field(2, 2)));
  });

  testOnMac('the readout names the wave mode, and moving the cursor changes it at once', (tester) async {
    await _pumpWelcome(tester);

    expect(find.text('WAVE MODE (m,n)'), findsOneWidget);
    expect(find.text('2,2'), findsOneWidget);
    expect(find.text('MOVE CURSOR TO SHIFT FREQUENCY'), findsOneWidget);

    await _mouseAt(tester, const Offset(600, 400));

    expect(find.text('3,3'), findsOneWidget);
    expect(find.text('2,2'), findsNothing);
  });

  testOnMac('the field eases into the mode the cursor picked', (tester) async {
    await _pumpWelcome(tester);
    await _mouseAt(tester, const Offset(600, 400));

    // One frame later the field has barely started towards 3,3.
    await tester.pump(const Duration(milliseconds: 16));

    expect(_drawn(tester), _field(2, 2, const Duration(milliseconds: 16)));

    // Pumped a frame at a time, as the easing is per frame.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(_drawn(tester), _field(3, 3, const Duration(milliseconds: 121 * 16)));
  });

  testOnMac('the field and the readout take no clicks: the buttons under the cursor still work', (tester) async {
    await _pumpWelcome(tester);

    await tester.tap(find.widgetWithText(QuantusButton, 'Create New Wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(WalletCreatedPage), findsOneWidget);
  });

  testOnMac('the top strip still drags the window over the moving field', (tester) async {
    final requests = recordWindowRequests(tester);
    await _pumpWelcome(tester);

    await tester.dragFrom(const Offset(600, 26), const Offset(80, 30));
    // Past the wait for a second click, which the strip also listens for.
    await tester.pump(const Duration(milliseconds: 400));

    expect(requests, ['startDrag']);
  });

  testOnMac('Import Wallet and Wallet Created have no field', (tester) async {
    await _pumpWelcome(tester);

    await tester.tap(find.widgetWithText(QuantusButton, 'Import Wallet'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportWalletPage), findsOneWidget);
    expect(find.byType(WaveField), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.tap(find.widgetWithText(QuantusButton, 'Create New Wallet'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(WalletCreatedPage), findsOneWidget);
    expect(find.byType(WaveField), findsNothing);
  });

  testOnMac('with reduced motion the field stands still and there is no readout', (tester) async {
    await _pumpWelcome(tester, reduceMotion: true);
    await _mouseAt(tester, const Offset(600, 400));

    await tester.pump(const Duration(seconds: 5));

    expect(_drawn(tester), _field(2, 2));
    expect(find.text('WAVE MODE (m,n)'), findsNothing);
    expect(find.text('MOVE CURSOR TO SHIFT FREQUENCY'), findsNothing);
  });

  testOnWindowsAndLinux('under the in-window menu bar the field fills the rest of the window', (tester) async {
    await _pumpWelcome(tester);

    final menuBarBottom = tester.getRect(find.byType(MenuBar)).bottom;
    expect(tester.getRect(find.byType(WaveField)), Rect.fromLTRB(0, menuBarBottom, 1200, 800));
  });
}
