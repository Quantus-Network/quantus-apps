import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/derivation_field.dart';
import 'package:quantus_cold_wallet/components/password_field.dart';
import 'package:quantus_cold_wallet/providers/sealed_wallet_controller.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/key_created_screen.dart';
import 'package:quantus_cold_wallet/screens/key_lost_screen.dart';
import 'package:quantus_cold_wallet/screens/migrate_vault_screen.dart';
import 'package:quantus_cold_wallet/screens/root_gate.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_cold_wallet/screens/show_secret_phrase_screen.dart';
import 'package:quantus_cold_wallet/screens/unlock_method_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/account_fixtures.dart' show coldApp, launcher;
import 'fakes/fake_cold_keys.dart';
import 'fakes/fault_injecting_storage.dart';
import 'fakes/wallet_fakes.dart';

const otherMnemonic = 'legal winner thank year wave sausage worth useful legal winner thank yellow';

class _OldVaultController extends SealedWalletController {
  final passwords = <String>[];

  @override
  WalletState build() => const WalletState(status: WalletStatus.needsMigration, biometricEnabled: true);

  @override
  Future<bool> migrateLegacy(String password, {required bool protected}) async {
    passwords.add(password);
    return true;
  }
}

class _KeyLostController extends SealedWalletController {
  @override
  WalletState build() => WalletState(status: WalletStatus.keyLost, accounts: testAccounts);
}

/// What the screens show and ask on a device that seals the recovery phrase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CheckphraseText.resolveOverride = (_) async => 'check phrase';

  late FakeColdKeys keys;

  setUp(() {
    FlutterSecureStoragePlatform.instance = FaultInjectingStorage();
    SharedPreferences.setMockInitialValues({});
    keys = FakeColdKeys();
  });

  /// A launch over what the keychain holds now, with [controller] standing in
  /// for the wallet when the state itself is what the test sets up.
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    bool biometrics = true,
    SealedWalletController Function() controller = SealedWalletController.new,
  }) async {
    final container = ProviderContainer(
      overrides: [
        walletControllerProvider.overrideWith(controller),
        coldKeyServiceProvider.overrideWithValue(keys),
        coldAuthServiceProvider.overrideWithValue(FakeColdAuth(biometrics: biometrics)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => awaitInit(container));
    return container;
  }

  Future<ProviderContainer> launchWithWallet(WidgetTester tester) async {
    final container = await launch(tester);
    await container
        .read(walletControllerProvider.notifier)
        .createWallet(mnemonic: testMnemonic, accounts: testAccounts, protected: true);
    return container;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container, Widget home) async {
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: coldApp(home)));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, ProviderContainer container, Widget screen) async {
    await pump(tester, container, launcher(screen));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  WalletState stateOf(ProviderContainer container) => container.read(walletControllerProvider);

  group('a new key', () {
    final screen = UnlockMethodScreen(mnemonic: testMnemonic, accounts: testAccounts);

    testWidgets('is created behind Face ID alone, with no passcode choice', (tester) async {
      final container = await launch(tester);
      await open(tester, container, screen);

      expect(find.text('Sign with Face ID'), findsOneWidget);
      expect(find.textContaining('Asked for every signature, with no passcode fallback.'), findsOneWidget);
      expect(find.text('Use Passcode only'), findsNothing);
      expect(keys.sealed, isNull);

      await tester.tap(find.text('Enable Face ID'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyCreatedScreen), findsOneWidget);
      expect(keys.sealed, testMnemonic);
      expect(stateOf(container).status, WalletStatus.unlocked);
      expect(stateOf(container).mnemonic, isNull);
    });

    testWidgets('is not created while Face ID is off, and there is no way around it', (tester) async {
      final container = await launch(tester, biometrics: false);
      await open(tester, container, screen);

      expect(find.text('Face ID is off'), findsOneWidget);
      expect(find.text(faceIdRequiredMessage), findsOneWidget);
      expect(find.text('Enable Face ID'), findsNothing);
      expect(find.text('Continue anyway'), findsNothing);

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(find.text('Face ID is off'), findsOneWidget);
      expect(keys.sealed, isNull);
      expect(stateOf(container).status, WalletStatus.needsSetup);
    });

    testWidgets('is not created by a dismissed Face ID prompt, which can be tried again', (tester) async {
      final container = await launch(tester);
      await open(tester, container, screen);
      keys.refuseNext = SealedKeyFailure.cancelled;

      await tester.tap(find.text('Enable Face ID'));
      await tester.pumpAndSettle();

      expect(find.text('Face ID was cancelled. Tap to try again.'), findsOneWidget);
      expect(keys.sealed, isNull);

      await tester.tap(find.text('Enable Face ID'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyCreatedScreen), findsOneWidget);
      expect(keys.sealed, testMnemonic);
    });
  });

  group('the recovery phrase', () {
    testWidgets('is shown only after its own Face ID prompt', (tester) async {
      final container = await launchWithWallet(tester);
      await pump(tester, container, const SettingsScreen());

      expect(find.textContaining('Face ID, every time.'), findsOneWidget);

      await tester.tap(find.text('Show secret phrase'));
      await tester.pumpAndSettle();

      expect(keys.prompts, 2);
      expect(find.byType(ShowSecretPhraseScreen), findsOneWidget);
      expect(find.text('abandon'), findsNothing);

      await tester.tap(find.text('Tap to reveal'));
      await tester.pump();
      expect(find.text('abandon'), findsNWidgets(11));
    });

    testWidgets('stays closed when the prompt is dismissed', (tester) async {
      final container = await launchWithWallet(tester);
      await pump(tester, container, const SettingsScreen());
      keys.refuseNext = SealedKeyFailure.cancelled;

      await tester.tap(find.text('Show secret phrase'));
      await tester.pumpAndSettle();

      expect(find.byType(ShowSecretPhraseScreen), findsNothing);
      expect(find.text('Could not confirm it is you.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('is put away when the app leaves the foreground', (tester) async {
      final container = await launchWithWallet(tester);
      await open(tester, container, const ShowSecretPhraseScreen(phrase: testMnemonic));
      expect(find.byType(ShowSecretPhraseScreen), findsOneWidget);

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(find.byType(ShowSecretPhraseScreen), findsNothing);
    });
  });

  testWidgets('an account is added with one prompt, and no address is derived before it', (tester) async {
    final container = await launchWithWallet(tester);
    await open(tester, container, const AddAccountScreen());
    await tester.tap(find.text('ADVANCED'));
    await tester.pumpAndSettle();

    expect(find.text('Face ID derives the address when you add this account.'), findsOneWidget);
    expect(keys.prompts, 1);

    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.byType(AddAccountScreen), findsNothing);
    expect(keys.prompts, 2);
    expect(stateOf(container).accounts.map((a) => a.label), ['Main key', 'Account 2']);
  });

  group('a key iOS removed', () {
    testWidgets('routes the app to its restore screen', (tester) async {
      final container = await launch(tester, controller: _KeyLostController.new);
      await pump(tester, container, const RootGate());

      expect(find.byType(KeyLostScreen), findsOneWidget);
      expect(find.text('Restore your key'), findsOneWidget);
      expect(find.text('Reset wallet…'), findsOneWidget);
    });

    testWidgets('comes back with the phrase of this wallet and no other', (tester) async {
      await launchWithWallet(tester);
      keys.sealed = null;
      final container = await launch(tester);
      expect(stateOf(container).status, WalletStatus.keyLost);
      await open(tester, container, const KeyLostScreen());

      await tester.tap(find.text('Enter Recovery Phrase'));
      await tester.pumpAndSettle();
      expect(find.byType(ImportWalletScreen), findsOneWidget);
      expect(find.text('Restore Key'), findsNWidgets(2));
      expect(find.byType(DerivationField), findsNothing);

      await tester.enterText(find.byType(TextField), otherMnemonic);
      await tester.pump();
      await tester.tap(find.widgetWithText(QuantusButton, 'Restore Key'));
      await tester.pumpAndSettle();
      expect(find.text('This recovery phrase belongs to a different wallet.'), findsOneWidget);
      expect(find.byType(UnlockMethodScreen), findsNothing);

      await tester.enterText(find.byType(TextField), testMnemonic);
      await tester.pump();
      await tester.tap(find.widgetWithText(QuantusButton, 'Restore Key'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable Face ID'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(KeyCreatedScreen), findsNothing);
      expect(keys.sealed, testMnemonic);
      expect(stateOf(container).status, WalletStatus.unlocked);
    });
  });

  group('a wallet behind an old device key', () {
    testWidgets('moves without asking for a password', (tester) async {
      final controller = _OldVaultController();
      final container = await launch(tester, controller: () => controller);
      await pump(tester, container, const MigrateVaultScreen());

      expect(find.text('Face ID for every signature'), findsOneWidget);
      expect(find.textContaining('Face ID is asked twice now'), findsOneWidget);
      expect(find.byType(PasswordField), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(controller.passwords, ['']);
    });

    testWidgets('stays where it is while Face ID is off', (tester) async {
      final controller = _OldVaultController();
      final container = await launch(tester, biometrics: false, controller: () => controller);
      await pump(tester, container, const MigrateVaultScreen());

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text(faceIdRequiredMessage), findsOneWidget);
      expect(controller.passwords, isEmpty);
    });
  });
}
