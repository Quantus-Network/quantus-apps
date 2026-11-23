import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/key_created_screen.dart';
import 'package:quantus_cold_wallet/screens/secure_element_warning_screen.dart';
import 'package:quantus_cold_wallet/screens/unlock_method_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'fakes/wallet_fakes.dart';

class _RecordingController extends WalletController {
  _RecordingController({this.failure});

  final Object? failure;
  final protectedCalls = <bool>[];

  @override
  WalletState build() => const WalletState(status: WalletStatus.needsSetup);

  @override
  Future<void> createWallet({
    required String mnemonic,
    required List<ColdAccount> accounts,
    required bool protected,
  }) async {
    protectedCalls.add(protected);
    if (failure != null) throw failure!;
    state = WalletState(status: WalletStatus.unlocked, mnemonic: mnemonic, accounts: accounts, biometricEnabled: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, {required FakeColdAuth auth, required _RecordingController controller}) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coldAuthServiceProvider.overrideWithValue(auth),
          walletControllerProvider.overrideWith(() => controller),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UnlockMethodScreen(mnemonic: testMnemonic, accounts: testAccounts),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers Face ID when biometrics are enrolled; enabling it creates a protected key', (tester) async {
    final controller = _RecordingController();
    await pump(tester, auth: FakeColdAuth(biometrics: true), controller: controller);

    expect(find.text('Unlock with Face ID'), findsOneWidget);
    expect(find.text('Enable Face ID'), findsOneWidget);
    expect(find.text('Use Passcode only'), findsOneWidget);
    expect(find.text('Your device may still offer Face ID first in the system prompt.'), findsOneWidget);
    expect(controller.protectedCalls, isEmpty);

    await tester.tap(find.text('Enable Face ID'));
    await tester.pumpAndSettle();

    expect(controller.protectedCalls, [true]);
    expect(find.byType(KeyCreatedScreen), findsOneWidget);
    expect(find.text('Key Created'), findsOneWidget);
    expect(find.text('Main key'), findsOneWidget);
    expect(find.text('Go To Wallet'), findsOneWidget);
    expect(find.byType(UnlockMethodScreen), findsNothing);
  });

  testWidgets('passcode only still stores the key behind user presence', (tester) async {
    final controller = _RecordingController();
    await pump(tester, auth: FakeColdAuth(biometrics: true), controller: controller);

    await tester.tap(find.text('Use Passcode only'));
    await tester.pumpAndSettle();

    expect(controller.protectedCalls, [true]);
    expect(find.byType(KeyCreatedScreen), findsOneWidget);
  });

  testWidgets('a cancelled prompt stays on the screen and can be retried', (tester) async {
    final controller = _RecordingController(failure: VaultAccessCancelled(PlatformException(code: 'cancel')));
    await pump(tester, auth: FakeColdAuth(biometrics: true), controller: controller);

    await tester.tap(find.text('Enable Face ID'));
    await tester.pumpAndSettle();

    expect(find.text('Face ID was cancelled. Tap to try again.'), findsOneWidget);
    expect(find.byType(KeyCreatedScreen), findsNothing);

    await tester.tap(find.text('Enable Face ID'));
    await tester.pumpAndSettle();
    expect(controller.protectedCalls, [true, true]);
  });

  testWidgets('a storage failure is shown and nothing moves on', (tester) async {
    final controller = _RecordingController(failure: Exception('keystore down'));
    await pump(tester, auth: FakeColdAuth(biometrics: true), controller: controller);

    await tester.tap(find.text('Enable Face ID'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Secure storage failed. Nothing was saved.'), findsOneWidget);
    expect(find.byType(KeyCreatedScreen), findsNothing);
  });

  testWidgets('a passcode-only device skips the choice', (tester) async {
    final controller = _RecordingController();
    await pump(tester, auth: FakeColdAuth(biometrics: false), controller: controller);

    expect(controller.protectedCalls, [true]);
    expect(find.text('Unlock with Face ID'), findsNothing);
    expect(find.byType(KeyCreatedScreen), findsOneWidget);
  });

  testWidgets('a passcode-only device can retry after a cancelled prompt', (tester) async {
    final controller = _RecordingController(failure: VaultAccessCancelled(PlatformException(code: 'cancel')));
    await pump(tester, auth: FakeColdAuth(biometrics: false), controller: controller);

    expect(find.text('Unlock with your passcode'), findsOneWidget);
    expect(find.text('Unlock was cancelled. Tap Continue to try again.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(controller.protectedCalls, [true, true]);
  });

  testWidgets('no device lock warns first; continuing stores a plain key', (tester) async {
    final controller = _RecordingController();
    await pump(tester, auth: FakeColdAuth(canProtect: false), controller: controller);

    expect(find.byType(SecureElementWarningScreen), findsOneWidget);
    expect(find.text('No device lock'), findsOneWidget);
    expect(controller.protectedCalls, isEmpty);

    await tester.tap(find.text('Continue anyway'));
    await tester.pumpAndSettle();

    expect(controller.protectedCalls, [false]);
    expect(find.byType(KeyCreatedScreen), findsOneWidget);
  });

  testWidgets('going back from the warning leaves the unlock step', (tester) async {
    final controller = _RecordingController();
    await pump(tester, auth: FakeColdAuth(canProtect: false), controller: controller);

    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();

    expect(find.byType(SecureElementWarningScreen), findsNothing);
    expect(find.byType(UnlockMethodScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(controller.protectedCalls, isEmpty);
  });

  testWidgets('Key Created cannot be left by going back', (tester) async {
    final controller = _RecordingController();
    await pump(tester, auth: FakeColdAuth(biometrics: false), controller: controller);
    expect(find.byType(KeyCreatedScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(KeyCreatedScreen), findsOneWidget);
  });
}
