import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/signing_refusal_view.dart';
import 'package:quantus_cold_wallet/components/ur_qr_panel.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

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
    final frames = List<String>.generate(7, (i) => 'ur:bytes/${i + 1}-7/abcd');
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

    expect(find.byType(AnimatedUrQr), findsOneWidget);
    expect(
      find.text('7 frames · ${ColdSettings.defaultQrFps} FPS · ${ColdSettings.defaultQrBytes} bytes'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.textContaining('keep both devices steady'), findsOneWidget);
  });

  testWidgets('UrQrPanel hides the pause control for a single frame', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          urQrFramesProvider.overrideWith((ref, payload) => const ['ur:bytes/abcd']),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: UrQrPanel(payload: UrPayload(Uint8List(5)))),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('1 frame ·'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('SigningRefusalView shows the reason, the detail and that nothing was signed', (tester) async {
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
    expect(tester.widget<Text>(find.text('Refused')).style?.color, colors.semanticEmber);
    expect(find.text('Because.'), findsOneWidget);
    expect(find.text('the detail'), findsOneWidget);
    expect(find.text('Nothing was signed.'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });
}
