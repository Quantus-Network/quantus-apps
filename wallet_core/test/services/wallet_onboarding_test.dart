import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';

import '../fakes.dart';

const _twelveWords = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _twentyFourWords = '$_twelveWords $_twelveWords';
const _scheme = DilithiumSchemeExtension.current;
final _rootPath = HdWalletService.pathForIndex(0, _scheme);

Account _found(int index) => Account(
  walletIndex: 0,
  index: index,
  name: 'Account ${index + 1}',
  accountId: 'qzFound$index',
  scheme: _scheme,
  derivationPath: HdWalletService.pathForIndex(index, _scheme),
);

/// Lets work that was started without being waited for run to its end.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

Future<bool> _neverAsked(Object error) => fail('the scan was not expected to fail: $error');

void main() {
  group('createSoftwareWallet', () {
    testWidgets('saves a generated phrase, makes "Account 1" active and adds the encrypted account', (tester) async {
      final bed = WalletTestBed(generatedMnemonic: _twelveWords);
      final ref = await pumpRef(tester, overrides: bed.overrides);

      final account = await createSoftwareWallet(ref);

      expect(bed.settings.mnemonics, {0: _twelveWords});
      expect(account.name, 'Account 1');
      expect(account.accountId, derivedAddress(_twelveWords, _rootPath));
      expect(account.walletIndex, 0);
      expect(account.derivationPath, _rootPath);
      expect(bed.settings.activeAccount?.account.accountId, account.accountId);
      expect(bed.settings.accounts.map((a) => a.accountId), [account.accountId, encryptedAddress(0)]);
      expect(bed.settings.origins, {0: WalletOrigin.created});
      expect(bed.settings.migrationDone, isTrue);
      expect(bed.pushRegistration.deviceRegistrations, 1);
    });

    testWidgets('fails when no phrase could be generated, and saves nothing', (tester) async {
      final bed = WalletTestBed(generatedMnemonic: '');
      final ref = await pumpRef(tester, overrides: bed.overrides);

      await expectLater(createSoftwareWallet(ref), throwsException);

      expect(bed.settings.mnemonics, isEmpty);
      expect(bed.settings.accounts, isEmpty);
    });
  });

  group('importSoftwareWallet', () {
    testWidgets('rejects a phrase that is not 12 or 24 words, and saves nothing', (tester) async {
      final bed = WalletTestBed();
      final ref = await pumpRef(tester, overrides: bed.overrides);

      await expectLater(
        importSoftwareWallet(ref, mnemonic: 'abandon abandon about', walletIndex: 0, onScanFailed: _neverAsked),
        throwsA(
          isA<InvalidRecoveryPhraseException>()
              .having((e) => e.message, 'message', 'Recovery phrase must be 12 or 24 words')
              // What the mobile app shows, unchanged from the plain Exception this replaced.
              .having((e) => '$e', 'as text', 'Exception: Recovery phrase must be 12 or 24 words'),
        ),
      );

      expect(bed.settings.mnemonics, isEmpty);
      expect(bed.settings.accounts, isEmpty);
    });

    testWidgets('saves a valid phrase with its root account and records the wallet as imported', (tester) async {
      final bed = WalletTestBed();
      final ref = await pumpRef(tester, overrides: bed.overrides);

      final root = await importSoftwareWallet(
        ref,
        mnemonic: '  $_twelveWords\n',
        walletIndex: 0,
        onScanFailed: _neverAsked,
      );

      expect(bed.settings.mnemonics, {0: _twelveWords});
      expect(root.name, 'Account 1');
      expect(root.accountId, derivedAddress(_twelveWords, _rootPath));
      expect(root.walletIndex, 0);
      expect(root.index, 0);
      expect(root.scheme, _scheme);
      expect(root.derivationPath, _rootPath);
      expect(bed.settings.activeAccount?.account.accountId, root.accountId);
      expect(bed.settings.origins, {0: WalletOrigin.imported});
      expect(bed.settings.migrationDone, isTrue);
      expect(bed.settings.referralChecked, isTrue);
      expect(bed.settings.seenPromoVideo, isTrue);
      expect(bed.pushRegistration.deviceRegistrations, 1);
      expect(bed.pushRegistration.registeredAddresses, isEmpty);
    });

    testWidgets('accepts a 24-word phrase', (tester) async {
      final bed = WalletTestBed();
      final ref = await pumpRef(tester, overrides: bed.overrides);

      await importSoftwareWallet(ref, mnemonic: _twentyFourWords, walletIndex: 0, onScanFailed: _neverAsked);

      expect(bed.settings.mnemonics, {0: _twentyFourWords});
    });

    testWidgets('adds the accounts the chain scan finds', (tester) async {
      final bed = WalletTestBed(
        scans: [
          () async => [_found(3)],
        ],
      );
      final ref = await pumpRef(tester, overrides: bed.overrides);

      final root = await importSoftwareWallet(ref, mnemonic: _twelveWords, walletIndex: 0, onScanFailed: _neverAsked);

      expect(bed.settings.accounts.take(2).map((a) => (a.name, a.accountId)), [
        ('Account 1', root.accountId),
        ('Account 2', 'qzFound3'),
      ]);
      expect(bed.settings.pendingScans, isEmpty);
    });

    testWidgets('does not wait for the encrypted account, and shows it in the account list once restored', (
      tester,
    ) async {
      final bed = WalletTestBed();
      final encryptedDerived = Completer<void>();
      bed.accounts.encryptedAccountsGate = encryptedDerived.future;
      final ref = await pumpRef(tester, overrides: bed.overrides);
      // An invalidated list reloads when it is next read.
      Future<List<String>?> listed() async {
        ref.read(accountsProvider);
        await _settle(tester);
        return ref.read(accountsProvider).value?.map((a) => a.accountId).toList();
      }

      final root = await importSoftwareWallet(ref, mnemonic: _twelveWords, walletIndex: 0, onScanFailed: _neverAsked);

      expect(await listed(), [root.accountId]);

      encryptedDerived.complete();
      await _settle(tester);

      expect(await listed(), [root.accountId, encryptedAddress(0)]);
      expect(bed.settings.accounts.last.name, 'Encrypted Account');
      expect(bed.encryptedStatesLoaded, [0]);
    });

    testWidgets('a failed scan is reported and the caller asked; saying yes scans again', (tester) async {
      final bed = WalletTestBed(
        scans: [
          () async => throw StateError('offline'),
          () async => [_found(1)],
        ],
      );
      final ref = await pumpRef(tester, overrides: bed.overrides);
      final asked = <Object>[];

      await importSoftwareWallet(
        ref,
        mnemonic: _twelveWords,
        walletIndex: 0,
        onScanFailed: (error) async {
          asked.add(error);
          return true;
        },
      );

      expect(asked.single, isStateError);
      expect(bed.telemetry.errors, ['Error discovering accounts']);
      expect(bed.discovery.calls, 2);
      expect(bed.settings.accounts.map((a) => a.accountId), contains('qzFound1'));
      expect(bed.settings.pendingScans, isEmpty);
    });

    testWidgets('declining to retry leaves the wallet imported with its scan still pending', (tester) async {
      final bed = WalletTestBed(scans: [() async => throw StateError('offline')]);
      final ref = await pumpRef(tester, overrides: bed.overrides);

      final root = await importSoftwareWallet(
        ref,
        mnemonic: _twelveWords,
        walletIndex: 0,
        onScanFailed: (_) async => false,
      );

      expect(bed.discovery.calls, 1);
      expect(bed.settings.mnemonics, {0: _twelveWords});
      expect(bed.settings.accounts.first.accountId, root.accountId);
      expect(bed.settings.pendingScans, {0: root.accountId});
      expect(bed.settings.origins, {0: WalletOrigin.imported});
    });

    testWidgets('a dev seed is imported without a scan (debug builds)', (tester) async {
      final bed = WalletTestBed();
      final ref = await pumpRef(tester, overrides: bed.overrides);

      await importSoftwareWallet(ref, mnemonic: AppConstants.crystalAlice, walletIndex: 0, onScanFailed: _neverAsked);

      expect(bed.settings.mnemonics, {0: AppConstants.crystalAlice});
      expect(bed.settings.accounts, hasLength(1));
      expect(bed.discovery.calls, 0);
      expect(bed.settings.pendingScans, isEmpty);
    });

    testWidgets('a further wallet is named after the accounts already here and registers its address for push', (
      tester,
    ) async {
      final bed = WalletTestBed();
      await bed.settings.addAccount(_found(0));
      final ref = await pumpRef(tester, overrides: bed.overrides);
      ref.read(accountsProvider);
      await tester.pump();

      final root = await importSoftwareWallet(ref, mnemonic: _twelveWords, walletIndex: 1, onScanFailed: _neverAsked);

      expect(root.name, 'Account 2');
      expect(root.walletIndex, 1);
      expect(bed.settings.mnemonics, {1: _twelveWords});
      expect(bed.pushRegistration.registeredAddresses, [root.accountId]);
      expect(bed.pushRegistration.deviceRegistrations, 0);
    });

    group('a phrase already in a wallet', () {
      Future<void> expectRefused(WidgetTester tester, WalletTestBed bed, String mnemonic) async {
        final accountsBefore = List.of(bed.settings.accounts);
        final mnemonicsBefore = Map.of(bed.settings.mnemonics);
        final ref = await pumpRef(tester, overrides: bed.overrides);

        await expectLater(
          importSoftwareWallet(ref, mnemonic: mnemonic, walletIndex: 1, onScanFailed: _neverAsked),
          throwsA(
            isA<InvalidRecoveryPhraseException>().having(
              (e) => e.message,
              'message',
              'This wallet is already in the app',
            ),
          ),
        );

        expect(bed.settings.mnemonics, mnemonicsBefore);
        expect(bed.settings.accounts, accountsBefore);
        expect(bed.settings.pendingScans, isEmpty);
        expect(bed.discovery.calls, 0);
      }

      testWidgets('is refused with a clear message, and nothing is stored', (tester) async {
        final bed = WalletTestBed();
        bed.settings.mnemonics[0] = _twelveWords;
        await bed.settings.addAccount(_found(0));

        await expectRefused(tester, bed, _twelveWords);
      });

      testWidgets('is still refused once that wallet\'s first account was disconnected', (tester) async {
        final bed = WalletTestBed();
        bed.settings.mnemonics[0] = _twelveWords;
        await bed.settings.addAccount(_found(1));

        await expectRefused(tester, bed, _twelveWords);
      });

      testWidgets('counts as the same with extra spaces', (tester) async {
        final bed = WalletTestBed();
        bed.settings.mnemonics[0] = _twelveWords;
        await bed.settings.addAccount(_found(0));

        await expectRefused(tester, bed, '  ${_twelveWords.replaceAll(' ', '   ')}\n');
      });
    });

    group('when saving the first account fails', () {
      testWidgets('leaves no phrase and no pending scan behind', (tester) async {
        final bed = WalletTestBed();
        bed.settings.addAccountError = StateError('disk full');
        final ref = await pumpRef(tester, overrides: bed.overrides);

        await expectLater(
          importSoftwareWallet(ref, mnemonic: _twelveWords, walletIndex: 0, onScanFailed: _neverAsked),
          throwsStateError,
        );

        expect(bed.settings.mnemonics, isEmpty);
        expect(bed.settings.pendingScans, isEmpty);
      });

      testWidgets('puts back a phrase the slot already held', (tester) async {
        final bed = WalletTestBed();
        bed.settings.mnemonics[1] = _twentyFourWords;
        bed.settings.addAccountError = StateError('disk full');
        final ref = await pumpRef(tester, overrides: bed.overrides);

        await expectLater(
          importSoftwareWallet(ref, mnemonic: _twelveWords, walletIndex: 1, onScanFailed: _neverAsked),
          throwsStateError,
        );

        expect(bed.settings.mnemonics, {1: _twentyFourWords});
        expect(bed.settings.pendingScans, isEmpty);
      });
    });
  });
}
