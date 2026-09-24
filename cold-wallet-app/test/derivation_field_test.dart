import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/derivation_field.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The derivation field's ADVANCED section: accounts are ML-DSA-87 by index or
/// by a custom path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ColdAccount? emitted;

  Future<void> pumpField(WidgetTester tester) async {
    emitted = null;
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Scaffold(body: DerivationField(onChanged: (a) => emitted = a)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ADVANCED'));
    await tester.pumpAndSettle();
  }

  testWidgets('an account index derives an ML-DSA-87 account', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), '2');
    await tester.pumpAndSettle();
    expect(emitted!.scheme, DilithiumScheme.mlDsa87);
    expect(emitted!.derivationPath, HdWalletService.pathForIndex(2, DilithiumScheme.mlDsa87));
    expect(find.text('ML-DSA-65'), findsNothing);
  });

  testWidgets('a custom full path is still accepted', (tester) async {
    await pumpField(tester);

    await tester.tap(find.text('Use a full derivation path'));
    await tester.pumpAndSettle();

    const customPath = "m/44'/189189'/7'/0'/0'";
    await tester.enterText(find.byType(TextField), customPath);
    await tester.pumpAndSettle();

    expect(emitted!.derivationPath, customPath);
    expect(emitted!.scheme, DilithiumScheme.mlDsa87);
  });
}
