import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/enlarged_qr_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'fakes/account_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEnlarged(WidgetTester tester) async {
    await tester.pumpWidget(coldApp(launcher(const EnlargedQrScreen(address: 'qzAddress', label: 'Main key'))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the label over a 330pt code', (tester) async {
    await pumpEnlarged(tester);

    expect(find.text('Main key'), findsOneWidget);
    expect(find.text('Tap anywhere to close'), findsOneWidget);
    expect(find.byType(QuantusQr), findsOneWidget);
    expect(tester.getSize(find.ancestor(of: find.byType(QuantusQr), matching: find.byType(FittedBox))).width, 330);
  });

  testWidgets('any tap closes it', (tester) async {
    await pumpEnlarged(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(EnlargedQrScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
