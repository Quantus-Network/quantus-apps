import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/account_menu.dart';

Account _account(int walletIndex, int index, {AccountType type = AccountType.local}) => Account(
  walletIndex: walletIndex,
  index: index,
  name: 'W${walletIndex}A$index',
  accountId: 'qzW${walletIndex}A$index',
  accountType: type,
);

MultisigAccount _multisig({String? creator}) => MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMe', 'qzOther', 'qzThird'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMe',
  creator: creator,
);

void main() {
  final a1 = _account(0, 1);
  final a2 = _account(0, 2);
  final encrypted = _account(0, 0, type: AccountType.encrypted);
  final keystone = _account(1, 0, type: AccountType.keystone);
  final second = _account(3, 0);

  group('accountMenuOf', () {
    test('a local account with a sibling offers address, rename, recovery phrase and disconnect', () {
      expect(accountMenuOf(a1, [a1, a2]), [
        AccountMenuItem.showAddress,
        AccountMenuItem.rename,
        AccountMenuItem.recoveryPhrase,
        AccountMenuItem.disconnect,
      ]);
    });

    test('the last local account of wallet 0 offers no disconnect, an encrypted sibling aside', () {
      expect(accountMenuOf(a1, [a1, encrypted]), [
        AccountMenuItem.showAddress,
        AccountMenuItem.rename,
        AccountMenuItem.recoveryPhrase,
      ]);
    });

    test('the last local account of another wallet offers disconnect', () {
      expect(accountMenuOf(second, [a1, second]), contains(AccountMenuItem.disconnect));
    });

    test('an encrypted account offers only its inner hash', () {
      expect(accountMenuOf(encrypted, [a1, a2, encrypted]), [AccountMenuItem.innerHash]);
    });

    test('a Keystone account alone in its wallet offers address, rename and disconnect', () {
      expect(accountMenuOf(keystone, [a1, keystone]), [
        AccountMenuItem.showAddress,
        AccountMenuItem.rename,
        AccountMenuItem.disconnect,
      ]);
    });

    test('a multisig offers address, rename, multisig details and disconnect', () {
      expect(multisigMenu, [
        AccountMenuItem.showAddress,
        AccountMenuItem.rename,
        AccountMenuItem.multisigDetails,
        AccountMenuItem.disconnect,
      ]);
    });
  });

  group('disconnectPlanOf', () {
    test('a local account with a sibling disconnects alone', () {
      expect(disconnectPlanOf(a2, [a1, a2]), DisconnectAccount(a2));
    });

    test('the last local account of a wallet takes the wallet, numbered among software wallets', () {
      // Stored at index 3, with a Keystone wallet at 1: the second software wallet.
      expect(
        disconnectPlanOf(second, [a1, keystone, second]),
        DisconnectWallet(second, walletIndex: 3, walletNumber: 2),
      );
    });

    test('a Keystone account disconnects as hardware', () {
      expect(disconnectPlanOf(keystone, [a1, keystone]), DisconnectHardware(keystone));
    });

    test('an encrypted account and the last local account of wallet 0 cannot be disconnected', () {
      expect(disconnectPlanOf(encrypted, [a1, a2, encrypted]), isNull);
      expect(disconnectPlanOf(a1, [a1, encrypted]), isNull);
    });

    test('an account missing from the list is an error', () {
      expect(() => disconnectPlanOf(second, [a1, a2]), throwsArgumentError);
    });
  });

  group('orderedSignersOf', () {
    test('puts a signing creator first and keeps the rest in stored order', () {
      expect(orderedSignersOf(_multisig(creator: 'qzThird')), ['qzThird', 'qzMe', 'qzOther']);
    });

    test('keeps the stored order when the creator is not a signer, or unknown', () {
      expect(orderedSignersOf(_multisig(creator: 'qzStranger')), ['qzMe', 'qzOther', 'qzThird']);
      expect(orderedSignersOf(_multisig()), ['qzMe', 'qzOther', 'qzThird']);
    });
  });

  group('nameEditOf', () {
    test('a new name is trimmed', () {
      expect(nameEditOf('Account 1', '  Savings  '), const NameChanged('Savings'));
    });

    test('a blank name is blank', () {
      expect(nameEditOf('Account 1', '   '), const NameBlank());
    });

    test('the current name, trimmed, is unchanged', () {
      expect(nameEditOf('Account 1', ' Account 1 '), const NameUnchanged());
    });
  });
}
