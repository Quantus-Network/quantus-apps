import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/migrate_vault_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'fakes/wallet_fakes.dart';

class _MigrationController extends WalletController {
  _MigrationController({this.failure});

  final Object? failure;
  final passwords = <String>[];
  bool wiped = false;

  @override
  WalletState build() => const WalletState(status: WalletStatus.needsMigration);

  @override
  Future<bool> migrateLegacy(String password) async {
    passwords.add(password);
    if (failure != null) throw failure!;
    if (password != 'alpha') return false;
    state = const WalletState(status: WalletStatus.unlocked, mnemonic: 'moved', biometricEnabled: true);
    return true;
  }

  @override
  Future<void> wipe() async {
    wiped = true;
    state = const WalletState(status: WalletStatus.needsSetup);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pump(WidgetTester tester, _MigrationController controller, {FakeColdAuth? auth}) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletControllerProvider.overrideWith(() => controller),
          coldAuthServiceProvider.overrideWithValue(auth ?? FakeColdAuth()),
        ],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const MigrateVaultScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('explains the one-time step', (tester) async {
    await pump(tester, _MigrationController());

    final title = tester.widget<Text>(find.text('One last password'));
    expect(title.style?.fontSize, text.titleHero.fontSize);
    expect(title.style?.color, colors.textContent);
    final body = tester.widget<Text>(find.textContaining('Enter your password once'));
    expect(body.style?.color, colors.textMuted);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('passes the password on and reports a wrong one', (tester) async {
    final controller = _MigrationController();
    await pump(tester, controller);

    await submit(tester, 'nope');

    expect(controller.passwords, ['nope']);
    final error = tester.widget<Text>(find.text('Incorrect password'));
    expect(error.style?.color, colors.semanticEmber);

    await submit(tester, 'alpha');
    expect(controller.passwords, ['nope', 'alpha']);
    expect(find.text('Incorrect password'), findsNothing);
  });

  testWidgets('a cancelled prompt asks for it again', (tester) async {
    await pump(tester, _MigrationController(failure: VaultAccessCancelled(PlatformException(code: 'cancel'))));

    await submit(tester, 'alpha');

    expect(find.text('Face ID is needed to finish moving your wallet.'), findsOneWidget);
  });

  testWidgets('a storage failure says nothing changed', (tester) async {
    await pump(tester, _MigrationController(failure: Exception('keystore down')));

    await submit(tester, 'alpha');

    expect(find.text('Secure storage failed. Nothing was changed.'), findsOneWidget);
  });

  testWidgets('without a device lock the rotation needs the explicit acceptance', (tester) async {
    final controller = _MigrationController();
    await pump(tester, controller, auth: FakeColdAuth(canProtect: false));
    await tester.enterText(find.byType(TextField), 'alpha');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('No device lock'), findsOneWidget);
    expect(controller.passwords, isEmpty);

    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('One last password'), findsOneWidget);
    expect(controller.passwords, isEmpty, reason: 'declining leaves the password vault as it is');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue anyway'));
    await tester.pumpAndSettle();
    expect(controller.passwords, ['alpha']);
  });

  testWidgets('reset is offered for a forgotten password', (tester) async {
    final controller = _MigrationController();
    await pump(tester, controller);

    await tester.tap(find.text('Reset wallet…'));
    await tester.pumpAndSettle();
    expect(find.text('Reset wallet?'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(controller.wiped, isTrue);
  });
}
