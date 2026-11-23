import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';

void main() {
  testWidgets('draws its text in capitals, and screen readers get it as written', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CapsText('Import Wallet', style: TextStyle(fontSize: 11))),
      ),
    );

    expect(find.text('IMPORT WALLET'), findsOneWidget);
    expect(find.bySemanticsLabel('Import Wallet'), findsOneWidget);
    expect(find.bySemanticsLabel('IMPORT WALLET'), findsNothing);
    expect(tester.widget<Text>(find.text('IMPORT WALLET')).style?.fontSize, 11);
  });
}
