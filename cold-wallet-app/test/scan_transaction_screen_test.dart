import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/scan_transaction_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();

  Future<void> pumpScan(WidgetTester tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const ScanTransactionScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 overlay, frame, and instruction tokens', (tester) async {
    await pumpScan(tester);

    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, colors.bgVoid);

    final instruction = tester.widget<Text>(find.textContaining('Scan the transaction QR from your hot wallet'));
    expect(instruction.style?.color, colors.textContent);
    expect(instruction.style?.fontSize, text.body.fontSize);

    expect(tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color, colors.textContent);
    expect(tester.widget<Icon>(find.byIcon(Icons.flash_on)).color, colors.textContent);

    final frame = tester.widgetList<Container>(find.byType(Container)).firstWhere((container) {
      final decoration = container.decoration;
      return decoration is BoxDecoration && decoration.border != null;
    });
    final decoration = frame.decoration! as BoxDecoration;
    expect((decoration.border as Border?)?.top.color, colors.accentFlare);
    expect(decoration.borderRadius, radius.mdBorder);

    final debugLabel = tester.widget<Text>(find.text('Debug calls'));
    expect(debugLabel.style?.color, colors.textVoid);
    expect(debugLabel.style?.fontSize, text.headingRow.fontSize);
  });
}
