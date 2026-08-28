import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/screens/set_password_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  testWidgets('uses v3 body and ember error tokens', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: SetPasswordScreen(
              mnemonic: 'test mnemonic',
              accounts: [ColdAccount(label: 'Account 1', index: 0)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final body = tester.widget<Text>(find.textContaining('Your password encrypts the wallet key'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.body.fontSize);

    await tester.enterText(find.byType(TextField).at(0), 'alpha');
    await tester.enterText(find.byType(TextField).at(1), 'beta');
    await tester.tap(find.text('Create wallet'));
    await tester.pump();

    final error = tester.widget<Text>(find.text('Passwords do not match'));
    expect(error.style?.color, colors.semanticEmber);
    expect(error.style?.fontSize, text.caption.fontSize);
  });
}
