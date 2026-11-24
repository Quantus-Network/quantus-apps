import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/sealed_wallet_controller.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_cold_wallet/ui/seal_wording.dart';

import 'fakes/fake_cold_keys.dart';
import 'fakes/fault_injecting_storage.dart';
import 'fakes/wallet_fakes.dart';

const otherMnemonic = 'legal winner thank year wave sausage worth useful legal winner thank yellow';

final second = ColdAccount(label: 'Account 2', index: 1, scheme: DilithiumScheme.mlDsa87);
final near65 = ColdAccount(label: 'NEAR', index: 0, scheme: DilithiumScheme.mlDsa65);

/// The wallet of a device that seals the recovery phrase: nothing is unlocked
/// for a session, and every use of the key is its own prompt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FaultInjectingStorage storage;
  late FakeColdKeys keys;
  late ProviderContainer container;
  final message = Uint8List.fromList([1, 2, 3]);

  /// A new process over the same device: its own controller.
  Future<ProviderContainer> launch({FakeColdAuth? auth}) async {
    final c = ProviderContainer(
      overrides: [
        walletControllerProvider.overrideWith(SealedWalletController.new),
        coldKeyServiceProvider.overrideWithValue(keys),
        coldAuthServiceProvider.overrideWithValue(auth ?? FakeColdAuth(biometrics: true)),
      ],
    );
    addTearDown(c.dispose);
    await awaitInit(c);
    return c;
  }

  setUp(() async {
    storage = FaultInjectingStorage();
    FlutterSecureStoragePlatform.instance = storage;
    keys = FakeColdKeys();
    container = await launch();
  });

  WalletState state() => container.read(walletControllerProvider);
  WalletController controller() => container.read(walletControllerProvider.notifier);
  String addressOf(ColdAccount account) => FakeColdKeys.keyOf(testMnemonic, account).address;

  Future<void> create([List<ColdAccount>? accounts]) =>
      controller().createWallet(mnemonic: testMnemonic, accounts: accounts ?? testAccounts, protected: true);

  test('starts in needsSetup with nothing stored', () {
    expect(state().status, WalletStatus.needsSetup);
    expect(controller().sealed, isTrue);
  });

  test('creation seals the phrase, proves it with one prompt and keeps only public keys', () async {
    await create();

    expect(state().status, WalletStatus.unlocked);
    expect(state().mnemonic, isNull);
    expect(keys.sealed, testMnemonic);
    expect(keys.prompted, ['Confirm your new signing key']);
    expect(container.read(addressesProvider).keys, [addressOf(testAccounts.single)]);
    expect(controller().phraseWords, 12);
    expect(storage.data.keys, [heldAccountsEntry]);
    expect(storage.data[heldAccountsEntry], isNot(contains('abandon')));
    expect(await controller().keyProtection(), KeyProtection.biometryEachUse);
  });

  test('a device with no biometric enrolled seals behind its passcode, and says so', () async {
    keys.available = SealPolicy.devicePasscode;

    await create();

    expect(keys.sealedUnder, SealPolicy.devicePasscode);
    expect(keys.prompts, 1);
    expect(await controller().keyProtection(), KeyProtection.passcodeEachUse);
  });

  test('a device without a screen lock seals nothing', () async {
    keys.available = null;

    await expectLater(create(), throwsA(isA<KeyRefused>().having((e) => e.message, 'message', lockRequiredMessage)));

    expect(keys.sealed, isNull);
    expect(storage.data, isEmpty);
    expect(state().status, WalletStatus.needsSetup);
  });

  group('a phrase behind the passcode', () {
    setUp(() async {
      keys.available = SealPolicy.devicePasscode;
      await create();
      keys.available = SealPolicy.biometry;
    });

    test('moves behind biometrics enrolled since, with a prompt under each', () async {
      await controller().sealBehindBiometrics();

      expect(keys.sealedUnder, SealPolicy.biometry);
      expect(keys.prompts, 3);
      expect(await controller().keyProtection(), KeyProtection.biometryEachUse);
    });

    test('stays there when the prompt is dismissed', () async {
      keys.refuseNext = SealedKeyFailure.cancelled;

      await expectLater(controller().sealBehindBiometrics(), throwsA(isA<VaultAccessCancelled>()));

      expect(keys.sealedUnder, SealPolicy.devicePasscode);
      expect(state().status, WalletStatus.unlocked);
    });
  });

  test('a dismissed confirmation leaves no wallet behind', () async {
    keys.refuseNext = SealedKeyFailure.cancelled;

    await expectLater(create(), throwsA(isA<VaultAccessCancelled>()));

    expect(keys.sealed, isNull);
    expect(storage.data, isEmpty);
    expect(state().status, WalletStatus.needsSetup);
  });

  test('a phrase that derives nothing is refused before anything is sealed', () async {
    await expectLater(controller().checkPhrase('not a phrase', testAccounts), throwsStateError);
    await expectLater(
      controller().createWallet(mnemonic: 'not a phrase', accounts: testAccounts, protected: true),
      throwsStateError,
    );

    expect(keys.sealed, isNull);
    expect(keys.prompts, 0);
  });

  test('a relaunch opens on the accounts without a prompt', () async {
    await create([testAccounts.single, near65]);

    final relaunched = await launch();

    expect(relaunched.read(walletControllerProvider).status, WalletStatus.unlocked);
    expect(relaunched.read(accountsProvider).map((a) => a.label), ['Main key', 'NEAR']);
    expect(relaunched.read(addressesProvider).keys, [addressOf(testAccounts.single), addressOf(near65)]);
    expect(keys.prompts, 1);
  });

  test('every signature is its own prompt', () async {
    await create([testAccounts.single, near65]);

    final signed = await controller().signExtrinsic(addressOf(testAccounts.single), message, specVersion: 148);
    expect(signed, [1, 2, 3, 148]);
    expect(keys.prompted.last, 'Sign this transaction');
    expect(keys.prompts, 2);

    expect(await controller().signNear(addressOf(near65), [7, 8]), [7, 8]);
    expect(keys.prompts, 3);
    expect(state().mnemonic, isNull);
  });

  test('a dismissed prompt signs nothing and changes nothing', () async {
    await create();
    keys.refuseNext = SealedKeyFailure.cancelled;

    await expectLater(
      controller().signExtrinsic(addressOf(testAccounts.single), message, specVersion: 148),
      throwsA(isA<VaultAccessCancelled>()),
    );

    expect(state().status, WalletStatus.unlocked);
  });

  test('a prompt that does not recognise the user is refused with what to do about it', () async {
    await create();
    keys.refuseNext = SealedKeyFailure.notRecognised;

    await expectLater(
      controller().signExtrinsic(addressOf(testAccounts.single), message, specVersion: 148),
      throwsA(isA<KeyRefused>().having((e) => e.message, 'message', contains('did not recognise you'))),
    );

    expect(state().status, WalletStatus.unlocked);
  });

  test('an account this wallet does not list cannot be signed for', () async {
    await create();

    await expectLater(controller().signExtrinsic(addressOf(second), message, specVersion: 148), throwsStateError);
    expect(keys.prompts, 1);
  });

  test('a public key is read without a prompt, and finds the owner of a NEAR key', () async {
    await create([testAccounts.single, near65]);
    final publicKey = controller().publicKeyOf(addressOf(near65));

    expect(publicKey, FakeColdKeys.keyOf(testMnemonic, near65).publicKey);
    expect(container.read(nearKeyOwnerProvider(hex.encode(publicKey))), addressOf(near65));
    expect(container.read(nearKeyOwnerProvider('00')), isNull);
    expect(keys.prompts, 1);
  });

  test('showing the phrase prompts each time, and a dismissed prompt shows nothing', () async {
    await create();

    expect(await controller().revealPhrase(), testMnemonic);
    expect(keys.prompts, 2);

    keys.refuseNext = SealedKeyFailure.cancelled;
    expect(await controller().revealPhrase(), isNull);
    expect(keys.prompts, 3);
  });

  test('adding an account is one prompt; renaming and removing are none', () async {
    await create();

    await controller().addAccount(second);
    expect(keys.prompts, 2);
    expect(container.read(addressesProvider).keys, [addressOf(testAccounts.single), addressOf(second)]);

    await controller().renameAccount(second, 'Savings');
    await controller().removeAccount(testAccounts.single);
    expect(keys.prompts, 2);
    expect(container.read(addressesProvider), {addressOf(second): isA<ColdAccount>()});
    expect(state().accounts.single.label, 'Savings');

    final relaunched = await launch();
    expect(relaunched.read(accountsProvider).single.label, 'Savings');
  });

  test('a dismissed prompt adds no account', () async {
    await create();
    keys.refuseNext = SealedKeyFailure.cancelled;

    await expectLater(controller().addAccount(second), throwsA(isA<VaultAccessCancelled>()));

    expect(state().accounts, hasLength(1));
  });

  group('a phrase the device destroyed', () {
    setUp(() async {
      await create([testAccounts.single, second]);
      keys.sealed = null;
    });

    test('is found at the next signature, which keeps the accounts listed', () async {
      await expectLater(
        controller().signExtrinsic(addressOf(second), message, specVersion: 148),
        throwsA(isA<KeyRefused>()),
      );

      expect(state().status, WalletStatus.keyLost);
      expect(state().accounts, hasLength(2));
    });

    test('is found at launch without a prompt', () async {
      final relaunched = await launch();

      expect(relaunched.read(walletControllerProvider).status, WalletStatus.keyLost);
      expect(relaunched.read(accountsProvider), hasLength(2));
      expect(keys.prompts, 1);
    });

    test('comes back only with the phrase of the listed accounts', () async {
      container = await launch();
      final accounts = state().accounts;

      await expectLater(controller().checkPhrase(otherMnemonic, accounts), throwsA(isA<KeyRefused>()));
      await expectLater(
        controller().createWallet(mnemonic: otherMnemonic, accounts: accounts, protected: true),
        throwsA(isA<KeyRefused>()),
      );
      expect(keys.sealed, isNull);
      expect(state().status, WalletStatus.keyLost);

      await controller().checkPhrase(testMnemonic, accounts);
      await controller().createWallet(mnemonic: testMnemonic, accounts: accounts, protected: true);

      expect(state().status, WalletStatus.unlocked);
      expect(keys.sealed, testMnemonic);
      expect(container.read(addressesProvider).keys, [addressOf(testAccounts.single), addressOf(second)]);
    });

    test('is forgotten with its accounts by a reset', () async {
      container = await launch();

      await controller().wipe();

      expect(state().status, WalletStatus.needsSetup);
      expect(storage.data, isEmpty);
    });
  });

  test('a sealed phrase without an account list is an unfinished creation, removed at launch', () async {
    keys.sealed = testMnemonic;

    final relaunched = await launch();

    expect(relaunched.read(walletControllerProvider).status, WalletStatus.needsSetup);
    expect(keys.sealed, isNull);
  });

  test('a reset removes the phrase and the account list', () async {
    await create();

    await controller().wipe();

    expect(keys.sealed, isNull);
    expect(storage.data, isEmpty);
    expect(state().status, WalletStatus.needsSetup);
    expect(container.read(addressesProvider), isEmpty);
  });

  group('a wallet an earlier version left in a vault', () {
    final accounts = [testAccounts.single, second];

    /// The vault as the version before this one kept it: behind a device key.
    Future<void> leaveDeviceKeyVault() async {
      final earlier = ProviderContainer(
        overrides: [
          walletControllerProvider.overrideWith(VaultWalletController.new),
          coldAuthServiceProvider.overrideWithValue(FakeColdAuth()),
        ],
      );
      addTearDown(earlier.dispose);
      await awaitInit(earlier);
      await vaultController(earlier).createWallet(mnemonic: testMnemonic, accounts: accounts, protected: true);
    }

    test('behind a device key moves without a password, and the vault goes last', () async {
      await leaveDeviceKeyVault();
      container = await launch();
      expect(state().status, WalletStatus.needsMigration);
      expect(state().biometricEnabled, isTrue);

      expect(await controller().migrateLegacy('', protected: true), isTrue);

      expect(state().status, WalletStatus.unlocked);
      expect(state().mnemonic, isNull);
      expect(state().accounts.map((a) => a.label), ['Main key', 'Account 2']);
      expect(keys.sealed, testMnemonic);
      expect(keys.prompts, 1);
      expect(storage.data.keys, [heldAccountsEntry]);
    });

    test('keeps its vault when the confirmation is dismissed', () async {
      await leaveDeviceKeyVault();
      container = await launch();
      keys.refuseNext = SealedKeyFailure.cancelled;

      await expectLater(controller().migrateLegacy('', protected: true), throwsA(isA<VaultAccessCancelled>()));

      expect(keys.sealed, isNull);
      expect(storage.data.keys, containsAll([vaultEntry, protectedKeyEntry]));
      expect(storage.data.containsKey(heldAccountsEntry), isFalse);
      expect(state().status, WalletStatus.needsMigration);
    });

    test('behind a password moves with it, and a wrong one changes nothing', () async {
      await VaultService().createVault(mnemonic: testMnemonic, password: 'hunter2', accounts: accounts);
      container = await launch();
      expect(state().status, WalletStatus.needsMigration);
      expect(state().biometricEnabled, isFalse);

      expect(await controller().migrateLegacy('wrong', protected: true), isFalse);
      expect(keys.sealed, isNull);
      expect(storage.data.keys, [vaultEntry]);

      expect(await controller().migrateLegacy('hunter2', protected: true), isTrue);
      expect(state().status, WalletStatus.unlocked);
      expect(keys.sealed, testMnemonic);
      expect(storage.data.keys, [heldAccountsEntry]);
    });

    test(
      'on a device whose key store prompts even to be looked into learns at the move that it has no device key',
      () async {
        await VaultService().createVault(mnemonic: testMnemonic, password: 'hunter2', accounts: accounts);
        container = await launch(auth: FakeColdAuth(storePromptsOnce: true));
        expect(state().biometricEnabled, isTrue);

        expect(await controller().migrateLegacy('', protected: true), isFalse);
        expect(state().biometricEnabled, isFalse);
        expect(keys.sealed, isNull);
        expect(storage.data.keys, [vaultEntry]);

        expect(await controller().migrateLegacy('hunter2', protected: true), isTrue);
        expect(keys.sealed, testMnemonic);
        expect(storage.data.keys, [heldAccountsEntry]);
      },
    );

    test('is gone after the move even when its key store refuses to open for the cleanup', () async {
      await leaveDeviceKeyVault();
      container = await launch();
      await controller().migrateLegacy('', protected: true);
      await VaultService().createVault(mnemonic: testMnemonic, password: 'hunter2', accounts: accounts);
      storage.unavailableKey = protectedKeyEntry;

      final relaunched = await launch();

      expect(relaunched.read(walletControllerProvider).status, WalletStatus.unlocked);
      expect(storage.data.keys, [heldAccountsEntry]);
    });

    test('is removed at launch when a move was cut off after sealing', () async {
      await leaveDeviceKeyVault();
      container = await launch();
      await controller().migrateLegacy('', protected: true);
      await VaultService().createVault(mnemonic: testMnemonic, password: 'hunter2', accounts: accounts);

      final relaunched = await launch();

      expect(relaunched.read(walletControllerProvider).status, WalletStatus.unlocked);
      expect(storage.data.keys, [heldAccountsEntry]);
    });

    test('goes with a reset before it was moved', () async {
      await leaveDeviceKeyVault();
      container = await launch();

      await controller().wipe();

      expect(state().status, WalletStatus.needsSetup);
      expect(storage.data, isEmpty);
    });
  });
}
