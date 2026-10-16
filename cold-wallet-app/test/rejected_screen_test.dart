import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  testWidgets('explains that nothing was signed and goes back to home', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RejectedScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sign'), findsOneWidget);
    expect(find.text('Nothing was signed'), findsOneWidget);
    expect(
      find.text('The transaction was discarded on this device. Your keys never left it and no funds moved.'),
      findsOneWidget,
    );
    expect(tester.widget<Text>(find.text('01')).style?.color, colors.semanticEmber);
    expect(find.text("Don't retry from the same phone"), findsOneWidget);
    expect(find.text("If it's compromised, retrying gives it another attempt."), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('Your funds are safe here'), findsOneWidget);
    expect(find.text('Move to a phone you trust before sending again.'), findsOneWidget);
    expect(
      find.text('If your phone showed different details from this screen, treat that phone as compromised.'),
      findsOneWidget,
    );
    expect(find.byType(Icon), findsNothing);

    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.byType(RejectedScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
