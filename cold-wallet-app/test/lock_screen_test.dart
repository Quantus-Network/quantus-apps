import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/lock_overlay.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class _LockedController extends WalletController {
  _LockedController({this.biometric = false});

  final bool biometric;

  @override
  WalletState build() => WalletState(status: WalletStatus.locked, biometricEnabled: biometric);

  @override
  Future<bool> unlockWithPassword(String password) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpLockScreen(WidgetTester tester, {_LockedController? controller}) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [if (controller != null) walletControllerProvider.overrideWith(() => controller)],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const LockScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 lock icon, title, and error tokens', (tester) async {
    await pumpLockScreen(tester, controller: _LockedController());

    final icon = tester.widget<Icon>(find.byIcon(Icons.lock_outline_rounded));
    expect(icon.color, colors.accentFlare);

    final title = tester.widget<Text>(find.text('Cold Wallet Locked'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleScreen.fontSize);
    expect(title.style?.fontWeight, text.titleScreen.fontWeight);

    await tester.tap(find.text('Unlock'));
    await tester.pump();

    final error = tester.widget<Text>(find.text('Incorrect password'));
    expect(error.style?.color, colors.semanticEmber);
    expect(error.style?.fontSize, text.caption.fontSize);
  });

  testWidgets('biometric button uses v3 content icon color', (tester) async {
    await pumpLockScreen(tester, controller: _LockedController(biometric: true));

    expect(find.text('Use biometrics'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.fingerprint));
    expect(icon.color, colors.textContent);
  });

  testWidgets('password field can be tapped when LockOverlay sits above the navigator', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletControllerProvider.overrideWith(_LockedController.new)],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: const SizedBox(),
            builder: (context, child) => Stack(children: [?child, const LockOverlay()]),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
