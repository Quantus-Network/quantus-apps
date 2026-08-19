import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/confirm_dialog.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpConfirm(WidgetTester tester, {required Future<void> Function(bool result) onResult}) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Reset wallet?',
                        message: 'This erases the encrypted key from this device.',
                        confirmLabel: 'Reset',
                      );
                      await onResult(confirmed);
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('presents QuantusDialog instead of AlertDialog', (tester) async {
    await pumpConfirm(tester, onResult: (_) async {});

    expect(find.byType(QuantusDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Reset wallet?'), findsOneWidget);
    expect(find.text('This erases the encrypted key from this device.'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('returns true when the QuantusDialog action is tapped', (tester) async {
    bool? result;
    await pumpConfirm(
      tester,
      onResult: (confirmed) async {
        result = confirmed;
      },
    );

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
