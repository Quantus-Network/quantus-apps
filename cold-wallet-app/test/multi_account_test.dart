import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_cold_wallet/theme/app_theme.dart';

import 'call_display_test.dart' show signerAddress;

const otherAddress = 'qzmNaLjPU7hcvkjHpGmrVDPD9y12vdAFimCSrP1GkhVFJMaUq';
const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

Future<void> pumpFor(WidgetTester tester, String signer, {required Map<String, ColdAccount> held}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressesProvider.overrideWith((ref) => held),
        addressCheckphraseProvider.overrideWith((ref, address) async => 'check phrase'),
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

class _AlwaysAuthenticates extends ColdAuthService {
  @override
  Future<bool> authenticate(String reason) async => true;

  @override
  Future<bool> canUseBiometrics() async => true;
}

void main() {
  group('the vault stays openable across a session', () {
    late WalletController controller;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      controller = container.read(walletControllerProvider.notifier);
    });

    test('rotating the password then adding an account leaves the vault openable', () async {
      await controller.createWallet(
        mnemonic: mnemonic,
        password: 'alpha',
        enableBiometric: false,
        accounts: [ColdAccount(label: 'One', index: 0)],
      );

      expect(
        await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta'),
        PasswordChangeResult.changed,
      );
      await controller.addAccount(ColdAccount(label: 'Two', index: 1));

      final reopened = await VaultService().unlockWithPassword('beta');
      expect(reopened.mnemonic, mnemonic);
      expect(reopened.accounts, hasLength(2));
    });

    test('an account can be added after a biometric unlock', () async {
      final container = ProviderContainer(
        overrides: [coldAuthServiceProvider.overrideWithValue(_AlwaysAuthenticates())],
      );
      addTearDown(container.dispose);
      final biometric = container.read(walletControllerProvider.notifier);

      await biometric.createWallet(
        mnemonic: mnemonic,
        password: 'alpha',
        enableBiometric: true,
        accounts: [ColdAccount(label: 'One', index: 0)],
      );
      biometric.lock();

      expect(await biometric.unlockWithBiometric(), isTrue);
      await biometric.addAccount(ColdAccount(label: 'Two', index: 1));

      expect(container.read(accountsProvider), hasLength(2));
      expect((await VaultService().unlockWithPassword('alpha')).accounts, hasLength(2));
    });
  });

  group('ColdAccount', () {
    test('an index fills the wallet template', () {
      expect(ColdAccount(label: 'a', index: 3).derivationPath, HdWalletService.pathForIndex(3));
    });

    test('a path is taken verbatim', () {
      expect(ColdAccount(label: 'a', path: "m/44'/189189'/9'/0'/0'").derivationPath, "m/44'/189189'/9'/0'/0'");
    });

    test('needs exactly one of index or path', () {
      expect(() => ColdAccount(label: 'a'), throwsArgumentError);
      expect(() => ColdAccount(label: 'a', index: 0, path: "m/44'"), throwsArgumentError);
      expect(() => ColdAccount(label: 'a', index: -1), throwsArgumentError);
      expect(() => ColdAccount(label: 'a', path: 'not a path'), throwsArgumentError);
    });
  });

  group('VaultContents', () {
    test('round-trips a multi-account vault', () {
      final contents = VaultContents(
        mnemonic: mnemonic,
        accounts: [
          ColdAccount(label: 'One', index: 0),
          ColdAccount(label: 'Two', path: "m/44'/189189'/7'/0'/0'"),
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
      await pumpFor(tester, signerAddress, held: {signerAddress: ColdAccount(label: 'One', index: 0)});

      expect(find.text('Sign'), findsOneWidget);
      expect(find.textContaining('does not hold'), findsNothing);
    });

    testWidgets('refuses when the wallet does not hold the signer', (tester) async {
      await pumpFor(tester, otherAddress, held: {signerAddress: ColdAccount(label: 'One', index: 0)});

      expect(find.textContaining('does not hold'), findsOneWidget);
      expect(find.text('Sign'), findsNothing);
    });
  });
}
