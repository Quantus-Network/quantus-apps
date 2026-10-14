import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/screens/enlarged_qr_screen.dart';
import 'package:quantus_cold_wallet/screens/rename_account_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'fakes/account_fixtures.dart';
import 'package:quantus_cold_wallet/components/cold_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const text = AppTextThemeV3.standard();

  Future<void> pumpShowKey(WidgetTester tester, List<ColdAccount> accounts, ColdAccount shown) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: accountOverrides(accounts),
        child: coldApp(launcher(ShowKeyScreen(address: fakeAddress(shown)))),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(KebabButton));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the label, the QR, the address and the lilac checkphrase', (tester) async {
    await pumpShowKey(tester, [one, two], two);

    expect(find.text('Account 2'), findsOneWidget);
    expect(find.text('Scan this with Quantus on your other phone.'), findsOneWidget);
    expect(find.byType(QuantusQr), findsOneWidget);
    expect(find.text('ADDRESS'), findsOneWidget);
    expect(find.text('CHECKPHRASE'), findsOneWidget);

    final address = tester.widget<Text>(find.text(fakeAddress(two)));
    expect(address.style?.fontFamily, text.dataAddressLarge.fontFamily);
    expect(address.style?.color, coldColors.textContent);

    final phrase = tester.widget<Text>(find.text('phrase'));
    expect(phrase.style?.color, coldColors.semanticLilac);
    expect(phrase.style?.fontFamily, text.dataAddressLarge.fontFamily);
    expect(find.text('PUBLIC KEY'), findsNothing);
  });

  testWidgets('an ML-DSA-65 account also offers its public key', (tester) async {
    await pumpShowKey(tester, [one, legacy65], legacy65);

    expect(find.text('PUBLIC KEY'), findsOneWidget);
    expect(find.widgetWithText(ColdButton, 'Show public key'), findsOneWidget);
  });

  testWidgets('the kebab lists the four options', (tester) async {
    await pumpShowKey(tester, [one, two], two);

    await openMenu(tester);

    for (final label in ['Show full screen', 'Show derivation path', 'Rename', 'Disconnect account']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Show derivation path opens a one-button dialog with the path', (tester) async {
    await pumpShowKey(tester, [one, two], two);

    await openMenu(tester);
    await tester.tap(find.text('Show derivation path'));
    await tester.pumpAndSettle();

    expect(find.text('Derivation Path'), findsOneWidget);
    expect(find.text(two.derivationPath), findsOneWidget);
    expect(find.textContaining('not a secret'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Derivation Path'), findsNothing);
    expect(find.byType(ShowKeyScreen), findsOneWidget);
  });

  testWidgets('Show full screen enlarges the code', (tester) async {
    await pumpShowKey(tester, [one, two], two);

    await openMenu(tester);
    await tester.tap(find.text('Show full screen'));
    await tester.pumpAndSettle();

    expect(find.byType(EnlargedQrScreen), findsOneWidget);
    expect(find.text('Tap anywhere to close'), findsOneWidget);
  });

  testWidgets('Rename opens the rename screen for this account', (tester) async {
    await pumpShowKey(tester, [one, two], two);

    await openMenu(tester);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(tester.widget<RenameAccountScreen>(find.byType(RenameAccountScreen)).account.label, 'Account 2');
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    await pumpShowKey(tester, [one, two], two);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ShowKeyScreen), findsNothing);
  });

  testWidgets('the only account cannot be disconnected', (tester) async {
    await pumpShowKey(tester, [one], one);

    await openMenu(tester);
    expect(find.textContaining('cannot be disconnected'), findsOneWidget);

    await tester.tap(find.text('Disconnect account'));
    await tester.pumpAndSettle();

    expect(find.text('Disconnect Account 1?'), findsNothing);
    expect(find.text('Disconnect account'), findsOneWidget);
  });
}
