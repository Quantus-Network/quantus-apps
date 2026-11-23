import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/scan_transaction_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFromHome(WidgetTester tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanTransactionScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Cancel Transaction leaves the scanner', (tester) async {
    await pumpFromHome(tester);

    await tester.tap(find.text('Cancel Transaction'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanTransactionScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
