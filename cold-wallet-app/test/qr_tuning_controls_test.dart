import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpControls(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667)),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.darkTheme(context),
              home: const Scaffold(body: QrTuningControls()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 caption, muted labels, content values, and flare slider chrome', (tester) async {
    await pumpControls(tester);

    for (final label in ['Frame rate', 'Bytes per frame']) {
      final widget = tester.widget<Text>(find.text(label));
      expect(widget.style?.color, colors.textMuted);
      expect(widget.style?.fontSize, text.caption.fontSize);
    }

    for (final value in ['15 FPS', '1100 bytes']) {
      final widget = tester.widget<Text>(find.text(value));
      expect(widget.style?.color, colors.textContent);
      expect(widget.style?.fontSize, text.caption.fontSize);
    }

    final themes = tester.widgetList<SliderTheme>(find.byType(SliderTheme));
    expect(themes, hasLength(2));
    for (final theme in themes) {
      expect(theme.data.activeTrackColor, colors.accentFlare);
      expect(theme.data.inactiveTrackColor, colors.borderHairline);
      expect(theme.data.thumbColor, colors.accentFlare);
      expect(theme.data.overlayColor, colors.accentFlare.useOpacity(0.15));
    }
  });
}
