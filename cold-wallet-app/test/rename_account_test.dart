import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/screens/rename_account_screen.dart';

import 'accounts_screen_test.dart' show pumpWithWallet, storedLabels, tapAndAwait, walletWith;
import 'fakes/account_fixtures.dart';

void main() {
  Future<void> pumpRename(WidgetTester tester) async {
    final container = (await tester.runAsync(() => walletWith([one, two])))!;
    await pumpWithWallet(tester, container, launcher(RenameAccountScreen(account: two)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  QuantusButton save(WidgetTester tester) => tester.widget<QuantusButton>(find.widgetWithText(QuantusButton, 'Save'));

  testWidgets('opens on the current name with the local-only caption', (tester) async {
    await pumpRename(tester);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);
    expect(find.text(accountNameHelper), findsOneWidget);
    expect(save(tester).isDisabled, isFalse);
  });

  testWidgets('saves a new name and goes back', (tester) async {
    await pumpRename(tester);

    await tester.enterText(find.byType(TextField), 'Savings');
    await tester.pump();
    await tapAndAwait(tester, find.text('Save'));

    expect(find.byType(RenameAccountScreen), findsNothing);
    expect(await tester.runAsync(storedLabels), ['Account 1', 'Savings']);
  });

  testWidgets('does not save a name another account already has', (tester) async {
    await pumpRename(tester);

    await tester.enterText(find.byType(TextField), 'Account 1');
    await tester.pump();

    expect(find.text('Another account is already named Account 1.'), findsOneWidget);
    expect(save(tester).isDisabled, isTrue);
  });

  testWidgets('does not save an empty name', (tester) async {
    await pumpRename(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    expect(save(tester).isDisabled, isTrue);
  });
}
