import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/root_gate.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class _InitErrorController extends WalletController {
  @override
  WalletState build() => const WalletState(status: WalletStatus.initializing, error: 'Could not read secure storage.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  testWidgets('init error uses v3 ember icon, title, and muted body tokens', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletControllerProvider.overrideWith(_InitErrorController.new)],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const RootGate()),
        ),
      ),
    );
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, colors.semanticEmber);

    final title = tester.widget<Text>(find.text('Storage error'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleScreen.fontSize);
    expect(title.style?.fontWeight, text.titleScreen.fontWeight);

    final body = tester.widget<Text>(find.text('Could not read secure storage.'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.body.fontSize);
  });
}
