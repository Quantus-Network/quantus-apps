import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: sheet),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration decorationAround(WidgetTester tester, String text) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  QuantusActionSheet accountSheet({VoidCallback? onCopy, VoidCallback? onRemove}) {
    return QuantusActionSheet(
      items: [
        QuantusActionSheetItem(label: 'Copy Address', onTap: onCopy ?? () {}),
        QuantusActionSheetItem(label: 'Edit Account', onTap: () {}),
        QuantusActionSheetItem(label: 'View Recovery Phrase', onTap: () {}),
        QuantusActionSheetItem(label: 'Remove Account', isDestructive: true, onTap: onRemove ?? () {}),
      ],
    );
  }

  testWidgets('shows item labels', (tester) async {
    await pumpSheet(tester, accountSheet());

    expect(find.text('Copy Address'), findsOneWidget);
    expect(find.text('Edit Account'), findsOneWidget);
    expect(find.text('View Recovery Phrase'), findsOneWidget);
    expect(find.text('Remove Account'), findsOneWidget);
  });

  testWidgets('tapping an item invokes its callback', (tester) async {
    var copied = false;
    await pumpSheet(tester, accountSheet(onCopy: () => copied = true));

    await tester.tap(find.text('Copy Address'));
    expect(copied, isTrue);
  });

  testWidgets('destructive label uses ember', (tester) async {
    await pumpSheet(tester, accountSheet());

    final destructive = tester.widget<Text>(find.text('Remove Account'));
    expect(destructive.style?.color, colors.semanticEmber);

    final regular = tester.widget<Text>(find.text('Copy Address'));
    expect(regular.style?.color, colors.textContent);
  });

  testWidgets('inserts a divider above the first destructive item', (tester) async {
    await pumpSheet(tester, accountSheet());

    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('omits the divider when no item is destructive', (tester) async {
    await pumpSheet(
      tester,
      QuantusActionSheet(
        items: [
          QuantusActionSheetItem(label: 'Rename Wallet', onTap: () {}),
          QuantusActionSheetItem(label: 'Add Account', onTap: () {}),
        ],
      ),
    );

    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('paints surface fill and emphasis border', (tester) async {
    await pumpSheet(tester, accountSheet());

    final decoration = decorationAround(tester, 'Copy Address');
    expect(decoration.color, colors.bgSurface);
    final border = decoration.border! as Border;
    expect(border.top.color, colors.borderEmphasis);
    expect(border.top.width, 1);
  });

  testWidgets('uses v3 lg radius', (tester) async {
    await pumpSheet(tester, accountSheet());

    expect(decorationAround(tester, 'Copy Address').borderRadius, const AppRadiusV3.standard().lgBorder);
  });

  testWidgets('showQuantusActionSheet pops then runs the tapped action', (tester) async {
    var copied = false;
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
                    onPressed: () {
                      showQuantusActionSheet(
                        context,
                        items: [QuantusActionSheetItem(label: 'Copy Address', onTap: () => copied = true)],
                      );
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
    expect(find.text('Copy Address'), findsOneWidget);

    await tester.tap(find.text('Copy Address'));
    await tester.pumpAndSettle();

    expect(copied, isTrue);
    expect(find.text('Copy Address'), findsNothing);
  });

  testWidgets('dismissing the sheet does not run actions', (tester) async {
    var copied = false;
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
                    onPressed: () {
                      showQuantusActionSheet(
                        context,
                        items: [QuantusActionSheetItem(label: 'Copy Address', onTap: () => copied = true)],
                      );
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
    expect(find.text('Copy Address'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(copied, isFalse);
    expect(find.text('Copy Address'), findsNothing);
  });
}
