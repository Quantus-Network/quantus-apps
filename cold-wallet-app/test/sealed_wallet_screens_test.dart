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
import 'package:quantus_cold_wallet/ui/seal_wording.dart';
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

/// What the screens show and ask on a device that seals the recovery phrase,
/// in the words of the platform they run on.
void main() {
  final iphone = TargetPlatformVariant.only(TargetPlatform.iOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  TestWidgetsFlutterBinding.ensureInitialized();
  CheckphraseText.resolveOverride = (_) async => 'check phrase';

  late FakeColdKeys keys;

  setUp(() {
    FlutterSecureStoragePlatform.instance = FaultInjectingStorage();
    SharedPreferences.setMockInitialValues({});
    keys = FakeColdKeys();
  });

  /// A launch over what the device holds now, with [controller] standing in
  /// for the wallet when the state itself is what the test sets up.
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    SealedWalletController Function() controller = SealedWalletController.new,
  }) async {
    final container = ProviderContainer(
      overrides: [
        walletControllerProvider.overrideWith(controller),
        coldKeyServiceProvider.overrideWithValue(keys),
        coldAuthServiceProvider.overrideWithValue(FakeColdAuth(biometrics: true)),
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
      expect(keys.sealedUnder, SealPolicy.biometry);
      expect(stateOf(container).status, WalletStatus.unlocked);
      expect(stateOf(container).mnemonic, isNull);
    }, variant: iphone);

    testWidgets('is created behind biometrics on Android, in its words', (tester) async {
      final container = await launch(tester);
      await open(tester, container, screen);

      expect(find.text('Sign with biometrics'), findsOneWidget);
      expect(find.textContaining('with no screen lock fallback. Changing biometrics'), findsOneWidget);

      await tester.tap(find.text('Enable biometrics'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyCreatedScreen), findsOneWidget);
      expect(keys.sealedUnder, SealPolicy.biometry);
    }, variant: android);

    testWidgets('is created behind the passcode where no biometric is enrolled, and told what that means', (
      tester,
    ) async {
      keys.available = SealPolicy.devicePasscode;
      final container = await launch(tester);
      await open(tester, container, screen);

      expect(find.text('Sign with your passcode'), findsOneWidget);
      expect(find.textContaining('Anyone who knows your passcode can sign, so set up Face ID'), findsOneWidget);
      expect(find.text('Enable Face ID'), findsNothing);

      await tester.tap(find.text('Use your passcode'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyCreatedScreen), findsOneWidget);
      expect(keys.sealedUnder, SealPolicy.devicePasscode);
    }, variant: iphone);

    testWidgets('is not created without a screen lock, and there is no way around it but setting one', (tester) async {
      keys.available = null;
      final container = await launch(tester);
      await open(tester, container, screen);

      expect(find.text('Set a passcode first'), findsOneWidget);
      expect(find.text(lockRequiredMessage), findsOneWidget);
      expect(find.text('Enable Face ID'), findsNothing);
      expect(find.text('Continue anyway'), findsNothing);

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(find.text('Set a passcode first'), findsOneWidget);
      expect(keys.sealed, isNull);
      expect(stateOf(container).status, WalletStatus.needsSetup);

      keys.available = SealPolicy.devicePasscode;
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(find.text('Sign with your passcode'), findsOneWidget);
    }, variant: iphone);

    testWidgets('is not created by a dismissed prompt, which can be tried again', (tester) async {
      final container = await launch(tester);
      await open(tester, container, screen);
      keys.refuseNext = SealedKeyFailure.cancelled;

      await tester.tap(find.text('Enable Face ID'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled. Tap to try again.'), findsOneWidget);
      expect(keys.sealed, isNull);

      await tester.tap(find.text('Enable Face ID'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyCreatedScreen), findsOneWidget);
      expect(keys.sealed, testMnemonic);
    }, variant: iphone);
  });

  group('a key behind the passcode', () {
    Future<ProviderContainer> launchBehindPasscode(WidgetTester tester) {
      keys.available = SealPolicy.devicePasscode;
      return launchWithWallet(tester);
    }

    testWidgets('is called the weaker way in Settings, with what would strengthen it', (tester) async {
      final container = await launchBehindPasscode(tester);
      await pump(tester, container, const SettingsScreen());

      expect(find.textContaining('Your passcode, every time. Weaker than Face ID'), findsOneWidget);
      expect(find.textContaining('Set up Face ID in the system settings to move the signing key'), findsOneWidget);
      expect(keys.prompts, 1);
    }, variant: iphone);

    testWidgets('moves behind Face ID from Settings once Face ID is set up', (tester) async {
      final container = await launchBehindPasscode(tester);
      keys.available = SealPolicy.biometry;
      await pump(tester, container, const SettingsScreen());

      await tester.tap(find.textContaining('Tap to move the signing key behind it.'));
      await tester.pumpAndSettle();

      expect(keys.sealedUnder, SealPolicy.biometry);
      expect(keys.prompted, ['Confirm your new signing key', 'Move your signing key', 'Move your signing key']);
      expect(find.textContaining('Face ID, every time.'), findsOneWidget);
    }, variant: iphone);

    testWidgets('stays behind the passcode when the move is dismissed', (tester) async {
      final container = await launchBehindPasscode(tester);
      keys.available = SealPolicy.biometry;
      await pump(tester, container, const SettingsScreen());
      keys.refuseNext = SealedKeyFailure.cancelled;

      await tester.tap(find.textContaining('Tap to move the signing key behind it.'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled. The signing key has not moved.'), findsOneWidget);
      expect(keys.sealedUnder, SealPolicy.devicePasscode);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }, variant: iphone);
  });

  group('the recovery phrase', () {
    testWidgets('is shown only after its own prompt', (tester) async {
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
    }, variant: iphone);

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

    expect(find.text('The address is derived when you add this account.'), findsOneWidget);
    expect(keys.prompts, 1);

    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.byType(AddAccountScreen), findsNothing);
    expect(keys.prompts, 2);
    expect(stateOf(container).accounts.map((a) => a.label), ['Main key', 'Account 2']);
  });

  group('a key the device removed', () {
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
    }, variant: iphone);
  });

  group('a wallet behind an old device key', () {
    testWidgets('moves without asking for a password', (tester) async {
      final controller = _OldVaultController();
      final container = await launch(tester, controller: () => controller);
      await pump(tester, container, const MigrateVaultScreen());

      expect(find.text('Face ID for every signature'), findsOneWidget);
      expect(find.textContaining('behind Face ID alone'), findsOneWidget);
      expect(find.textContaining('You are asked up to twice now'), findsOneWidget);
      expect(find.byType(PasswordField), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(controller.passwords, ['']);
    }, variant: iphone);

    testWidgets('says it moves behind the passcode where no biometric is enrolled', (tester) async {
      keys.available = SealPolicy.devicePasscode;
      final container = await launch(tester, controller: _OldVaultController.new);
      await pump(tester, container, const MigrateVaultScreen());

      expect(find.text('Your passcode for every signature'), findsOneWidget);
      expect(find.textContaining('behind your passcode alone'), findsOneWidget);
    }, variant: iphone);

    testWidgets('stays where it is until the phone has a screen lock', (tester) async {
      keys.available = null;
      final controller = _OldVaultController();
      final container = await launch(tester, controller: () => controller);
      await pump(tester, container, const MigrateVaultScreen());

      expect(find.text('Set a screen lock first'), findsOneWidget);
      expect(find.text(lockRequiredMessage), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      keys.available = SealPolicy.devicePasscode;
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('Your screen lock for every signature'), findsOneWidget);
      expect(controller.passwords, isEmpty);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(controller.passwords, ['']);
    });
  });
}
