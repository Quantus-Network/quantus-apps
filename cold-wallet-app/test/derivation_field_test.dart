import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/derivation_field.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The derivation field's ADVANCED section: the signature-type toggle sets the
/// scheme (and its derivation path), while custom paths are still allowed.
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

  testWidgets('the signature type sets the scheme and its derivation path', (tester) async {
    await pumpField(tester);

    await tester.tap(find.text('ML-DSA-87'));
    await tester.pumpAndSettle();
    expect(emitted!.scheme, DilithiumScheme.mlDsa87);
    expect(emitted!.derivationPath, HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa87));
    expect(emitted!.derivationPath, endsWith("/0'"));

    await tester.tap(find.text('ML-DSA-65'));
    await tester.pumpAndSettle();
    expect(emitted!.scheme, DilithiumScheme.mlDsa65);
    expect(emitted!.derivationPath, endsWith("/1'"));
  });

  testWidgets('a custom full path is still accepted', (tester) async {
    await pumpField(tester);

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
