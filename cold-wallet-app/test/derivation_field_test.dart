import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/derivation_field.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The derivation field: the signature-type toggle on screen sets the scheme
/// (and its derivation path), while ADVANCED still allows custom paths.
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
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    await tester.tap(find.text('ADVANCED'));
    await tester.pumpAndSettle();
  }

  testWidgets('the signature type is on screen and sets the scheme and its derivation path', (tester) async {
    await pumpField(tester);

    expect(find.text('ML-DSA-87'), findsOneWidget);
    expect(find.text('Account index'), findsNothing);
    // The default sits first.
    expect(tester.getTopLeft(find.text('ML-DSA-87')).dx, lessThan(tester.getTopLeft(find.text('ML-DSA-65')).dx));

    await tester.tap(find.text('ML-DSA-65'));
    await tester.pumpAndSettle();
    expect(emitted!.scheme, DilithiumScheme.mlDsa65);
    expect(emitted!.derivationPath, HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa65));
    expect(emitted!.derivationPath, endsWith("/1'"));

    await tester.tap(find.text('ML-DSA-87'));
    await tester.pumpAndSettle();
    expect(emitted!.scheme, DilithiumScheme.mlDsa87);
    expect(emitted!.derivationPath, endsWith("/0'"));
  });

  testWidgets('an ML-DSA-65 template path restores an ML-DSA-65 account', (tester) async {
    await pumpField(tester);
    await openAdvanced(tester);

    await tester.tap(find.text('Use a full derivation path'));
    await tester.pumpAndSettle();

    final path65 = HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa65);
    await tester.enterText(find.byType(TextField), path65);
    await tester.pumpAndSettle();

    expect(emitted!.derivationPath, path65);
    expect(emitted!.scheme, DilithiumScheme.mlDsa65);
  });

  testWidgets('a custom full path is still accepted', (tester) async {
    await pumpField(tester);
    await openAdvanced(tester);

    await tester.tap(find.text('Use a full derivation path'));
    await tester.pumpAndSettle();

    const customPath = "m/44'/189189'/7'/0'/0'";
    await tester.enterText(find.byType(TextField), customPath);
    await tester.pumpAndSettle();

    expect(emitted!.derivationPath, customPath);
    // The trailing 0' marks this custom path as ML-DSA-87.
    expect(emitted!.scheme, DilithiumScheme.mlDsa87);
  });
}
