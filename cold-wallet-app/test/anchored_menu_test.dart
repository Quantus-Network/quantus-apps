import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

import 'fakes/account_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? tapped;

  Future<void> pumpMenu(WidgetTester tester) async {
    tapped = null;
    await tester.pumpWidget(
      coldApp(
        Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Builder(
              builder: (anchor) => TextButton(
                onPressed: () => showAnchoredMenu(
                  anchor,
                  anchor: anchor,
                  groups: [
                    [
                      AnchoredMenuItem(label: 'First', onTap: () => tapped = 'First'),
                      const AnchoredMenuItem(label: 'Inert', caption: 'Not now.'),
                    ],
                    [AnchoredMenuItem(label: 'Delete', isDestructive: true, onTap: () => tapped = 'Delete')],
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens under the anchor, inside the screen', (tester) async {
    await pumpMenu(tester);

    final anchor = tester.getRect(find.text('open'));
    final first = tester.getRect(find.text('First'));
    expect(first.top, greaterThan(anchor.bottom));
    expect(first.right, lessThanOrEqualTo(anchor.right));
    expect(find.text('Inert'), findsOneWidget);
    expect(find.text('Not now.'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Delete')).style?.color, coldColors.semanticEmber);
  });

  testWidgets('an item closes the menu and then runs', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();

    expect(tapped, 'First');
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('an inert item does nothing', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.text('Inert'));
    await tester.pumpAndSettle();

    expect(tapped, isNull);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('the scrim closes it', (tester) async {
    await pumpMenu(tester);

    await tester.tapAt(const Offset(10, 590));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsNothing);
    expect(tapped, isNull);
  });

  testWidgets('back closes it', (tester) async {
    await pumpMenu(tester);

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Escape closes it', (tester) async {
    await pumpMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsNothing);
  });
}
