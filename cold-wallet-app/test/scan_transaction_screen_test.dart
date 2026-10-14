import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_cold_wallet/screens/scan_transaction_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpScan(WidgetTester tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const ScanTransactionScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the Sign chrome, the step header, the bracket frame and the receiving panel', (tester) async {
    await pumpScan(tester);

    expect(find.text('Sign'), findsOneWidget);
    expect(find.text('Torch'), findsOneWidget);
    expect(tester.widget<Text>(find.text('STEP 1/3')).style?.color, colors.accentFlare);
    expect(tester.widget<Text>(find.text('Scan the transaction')).style?.fontSize, text.titleScreen.fontSize);
    expect(find.text("Hold this device over your phone's screen to load the transaction."), findsOneWidget);

    expect(find.byType(MobileScanner), findsOneWidget);
    final painter =
        tester
                .widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter))
                .painter
            as ScanFramePainter;
    expect(painter.accent, colors.accentFlare);

    final label = tester.widget<Text>(find.text('RECEIVING TRANSACTION'));
    expect(label.style?.color, colors.textMuted);
    expect(label.style?.fontFamily, AppTextThemeV3.fontFamilySecondary);
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.color, colors.accentFlare);
    expect(bar.minHeight, 4);

    final cancel = tester.widget<Text>(find.text('Cancel Transaction'));
    expect(cancel.style?.decoration, TextDecoration.underline);
    expect(find.text('Debug calls'), findsOneWidget);
    expect(find.byType(Icon), findsNothing, reason: 'the cold wallet draws no Material icons');
  });

  testWidgets('shows no scanning tips before any frame has arrived', (tester) async {
    await pumpScan(tester);

    await tester.pump(ScanTransactionScreen.stallTimeout * 2);

    expect(find.text('Scan the transaction'), findsOneWidget);
    expect(find.text('Not picking up new frames'), findsNothing);
    expect(find.text('RECEIVING TRANSACTION'), findsOneWidget);
  });
}
