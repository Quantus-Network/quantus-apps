import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/signing_refusal_view.dart';
import 'package:quantus_cold_wallet/components/ur_qr_panel.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final pauseButton = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Pause and tune');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpPanel(WidgetTester tester, List<String> frames) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [urQrFramesProvider.overrideWith((ref, payload) => frames)],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: UrQrPanel(payload: UrPayload(Uint8List(5000)))),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('UrPayload', () {
    test('is equal by content, so two screens share one frame set', () {
      final a = UrPayload(Uint8List.fromList([1, 2, 3]));
      final b = UrPayload(Uint8List.fromList([1, 2, 3]));
      final c = UrPayload(Uint8List.fromList([1, 2, 4]));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('qrPausedProvider', () {
    test('starts running and toggles', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(qrPausedProvider), isFalse);
      container.read(qrPausedProvider.notifier).pause();
      expect(container.read(qrPausedProvider), isTrue);
      container.read(qrPausedProvider.notifier).resume();
      expect(container.read(qrPausedProvider), isFalse);
    });
  });

  testWidgets('UrQrPanel shows the frame summary and a pause control for animated payloads', (tester) async {
    await pumpPanel(tester, List<String>.generate(7, (i) => 'ur:bytes/${i + 1}-7/abcd'));

    expect(find.byType(AnimatedUrQr), findsOneWidget);
    expect(
      find.text('7 frames · ${ColdSettings.defaultQrFps} FPS · ${ColdSettings.defaultQrBytes} bytes'),
      findsOneWidget,
    );
    expect(pauseButton, findsOneWidget);
    expect(find.textContaining('keep both devices steady'), findsOneWidget);
  });

  testWidgets('UrQrPanel hides the pause control for a single frame', (tester) async {
    await pumpPanel(tester, const ['ur:bytes/abcd']);

    expect(find.textContaining('1 frame ·'), findsOneWidget);
    expect(pauseButton, findsNothing);
  });

  testWidgets('UrQrPanel draws the frame progress', (tester) async {
    await pumpPanel(tester, List<String>.generate(7, (i) => 'ur:bytes/${i + 1}-7/abcd'));

    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.color, colors.accentFlare);
    expect(bar.value, closeTo(1 / 7, 0.001));

    await tester.pump(const Duration(milliseconds: 1000 ~/ ColdSettings.defaultQrFps + 1));
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, closeTo(2 / 7, 0.001));
  });

  testWidgets('SigningRefusalView shows the reason, the detail, that nothing was signed, and leads to Rejected', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: const SigningRefusalView(
            appBarTitle: 'Sign Something',
            title: 'Refused',
            message: 'Because.',
            detail: Text('the detail'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sign Something'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Refused')).style?.color, colors.textContent);
    expect(find.text('Because.'), findsOneWidget);
    expect(find.text('the detail'), findsOneWidget);
    expect(find.text('Nothing was signed.'), findsOneWidget);

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.byType(RejectedScreen), findsOneWidget);
    expect(find.byType(SigningRefusalView), findsNothing);
  });
}
