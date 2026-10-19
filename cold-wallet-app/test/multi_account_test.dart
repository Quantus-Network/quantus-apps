import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

import 'call_display_test.dart' show signerAddress;
import 'fakes/wallet_fakes.dart';

const otherAddress = 'qzmNaLjPU7hcvkjHpGmrVDPD9y12vdAFimCSrP1GkhVFJMaUq';
const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

Future<void> pumpFor(WidgetTester tester, String signer, {required Map<String, ColdAccount> held}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressesProvider.overrideWith((ref) => held),
        checksumNameProvider.overrideWith((ref, address) async => 'check phrase'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: AppTheme.darkTheme(context),
            child: SignTransactionScreen(
              request: SigningRequest(
                signer: signer,
                payload: SigningRequest.decode(DebugPayloads.governanceVoteAye()).payload,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the vault stays openable across a session', () {
    late ProviderContainer container;
    late WalletController controller;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      container = ProviderContainer(overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth())]);
      addTearDown(container.dispose);
      controller = container.read(walletControllerProvider.notifier);
      await awaitInit(container);
    });

    test('moving a password vault to the device key then adding an account leaves the vault openable', () async {
      await VaultService().createVault(
        mnemonic: mnemonic,
        password: 'alpha',
        accounts: [ColdAccount(label: 'One', index: 0, scheme: DilithiumScheme.mlDsa87)],
      );
      final migrated = ProviderContainer(overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth())]);
      addTearDown(migrated.dispose);
      final legacy = migrated.read(walletControllerProvider.notifier);
      await awaitInit(migrated);

      expect(await legacy.migrateLegacy('alpha', protected: true), isTrue);
      await legacy.addAccount(ColdAccount(label: 'Two', index: 1, scheme: DilithiumScheme.mlDsa87));

      final reopened = await VaultService().unlockWithBiometricKey();
      expect(reopened.mnemonic, mnemonic);
      expect(reopened.accounts, hasLength(2));
    });

    test('an account can be added after a device-key unlock', () async {
      await controller.createWallet(
        mnemonic: mnemonic,
        accounts: [ColdAccount(label: 'One', index: 0, scheme: DilithiumScheme.mlDsa87)],
        protected: true,
      );
      controller.lock();

      expect(await controller.unlockWithBiometric(), isTrue);
      await controller.addAccount(ColdAccount(label: 'Two', index: 1, scheme: DilithiumScheme.mlDsa87));

      expect(container.read(accountsProvider), hasLength(2));
      expect((await VaultService().unlockWithBiometricKey()).accounts, hasLength(2));
    });
  });

  group('ColdAccount', () {
    test('an index fills the wallet template', () {
      expect(
        ColdAccount(label: 'a', index: 3, scheme: DilithiumScheme.mlDsa87).derivationPath,
        HdWalletService.pathForIndex(3, DilithiumScheme.mlDsa87),
      );
    });

    test('a path is taken verbatim', () {
      expect(
        ColdAccount(label: 'a', path: "m/44'/189189'/9'/0'/0'", scheme: DilithiumScheme.mlDsa87).derivationPath,
        "m/44'/189189'/9'/0'/0'",
      );
    });

    test('needs exactly one of index or path', () {
      expect(() => ColdAccount(label: 'a', scheme: DilithiumScheme.mlDsa87), throwsArgumentError);
      expect(
        () => ColdAccount(label: 'a', index: 0, path: "m/44'", scheme: DilithiumScheme.mlDsa87),
        throwsArgumentError,
      );
      expect(() => ColdAccount(label: 'a', index: -1, scheme: DilithiumScheme.mlDsa87), throwsArgumentError);
      expect(() => ColdAccount(label: 'a', path: 'not a path', scheme: DilithiumScheme.mlDsa87), throwsArgumentError);
    });
  });

  group('VaultContents', () {
    test('round-trips a multi-account vault', () {
      final contents = VaultContents(
        mnemonic: mnemonic,
        accounts: [
          ColdAccount(label: 'One', index: 0, scheme: DilithiumScheme.mlDsa87),
          ColdAccount(label: 'Two', path: "m/44'/189189'/7'/0'/0'", scheme: DilithiumScheme.mlDsa87),
        ],
      );
      final decoded = VaultContents.decode(contents.encode());

      expect(decoded.mnemonic, mnemonic);
      expect(decoded.accounts.map((a) => a.derivationPath), contents.accounts.map((a) => a.derivationPath));
    });

    test('reads a vault written before the account list as one account at index 0', () {
      final decoded = VaultContents.decode(mnemonic);

      expect(decoded.mnemonic, mnemonic);
      expect(decoded.accounts, hasLength(1));
      expect(decoded.accounts.single.index, 0);
    });
  });

  group('the signing screen matches the request to an account', () {
    testWidgets('signs when the wallet holds the signer', (tester) async {
      await pumpFor(
        tester,
        signerAddress,
        held: {signerAddress: ColdAccount(label: 'One', index: 0, scheme: DilithiumScheme.mlDsa87)},
      );

      expect(find.widgetWithText(QuantusButton, 'Approve and Sign'), findsOneWidget);
      expect(find.textContaining('does not exist in this cold wallet'), findsNothing);
    });

    testWidgets('refuses when the wallet does not hold the signer', (tester) async {
      await pumpFor(
        tester,
        otherAddress,
        held: {signerAddress: ColdAccount(label: 'One', index: 0, scheme: DilithiumScheme.mlDsa87)},
      );

      expect(find.textContaining('does not exist in this cold wallet'), findsOneWidget);
      expect(find.widgetWithText(QuantusButton, 'Approve and Sign'), findsNothing);
    });
  });
}
