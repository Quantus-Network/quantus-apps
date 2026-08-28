import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/multisig_threshold_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpSlider(WidgetTester tester, {int threshold = 2, int signerCount = 3}) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: MultisigThresholdSlider(
                threshold: threshold,
                signerCount: signerCount,
                label: 'THRESHOLD',
                valueLabel: '$threshold of $signerCount',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 surface, label data, flare value, and slider chrome', (tester) async {
    await pumpSlider(tester);

    final label = tester.widget<Text>(find.text('THRESHOLD'));
    expect(label.style?.color, colors.textMuted);
    expect(label.style?.fontSize, text.labelData.fontSize);
    expect(label.style?.fontWeight, text.labelData.fontWeight);

    final value = tester.widget<Text>(find.text('2 of 3'));
    expect(value.style?.color, colors.accentFlare);
    expect(value.style?.fontSize, text.labelData.fontSize);
    expect(value.style?.fontWeight, text.labelData.fontWeight);

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('THRESHOLD'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface);
    expect(decoration.borderRadius, const AppRadiusV3.standard().mdBorder);

    final theme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(theme.data.activeTrackColor, colors.accentFlare);
    expect(theme.data.inactiveTrackColor, colors.borderHairline);
    expect(theme.data.thumbColor, colors.accentFlare);
    expect(theme.data.overlayColor, colors.accentFlare.useOpacity(0.15));
  });
}
