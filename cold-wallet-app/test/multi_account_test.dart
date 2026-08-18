import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';
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

void main() {
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
