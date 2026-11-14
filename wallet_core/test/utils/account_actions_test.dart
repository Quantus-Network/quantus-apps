import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/account_actions.dart';

const _local = RegularAccount(Account(walletIndex: 0, index: 0, name: 'Main', accountId: 'qzLocal'));
const _keystone = RegularAccount(
  Account(walletIndex: 1, index: 0, name: 'Cold', accountId: 'qzKeystone', accountType: AccountType.keystone),
);
const _encrypted = RegularAccount(
  Account(walletIndex: 0, index: 0, name: 'Encrypted', accountId: 'qzEncrypted', accountType: AccountType.encrypted),
);
final _multisig = MultisigDisplayAccount(
  MultisigAccount(
    name: 'Team',
    accountId: 'qzMultisig',
    signers: const ['qzLocal', 'qzOther'],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: 'qzLocal',
  ),
);
const _entrusted = EntrustedDisplayAccount(
  EntrustedAccount(parentAccountId: 'qzLocal', index: 0, name: 'Entrusted', accountId: 'qzEntrusted'),
);

const _receive = AccountAction(AccountActionKind.receive);
const _send = AccountAction(AccountActionKind.send);
const _propose = AccountAction(AccountActionKind.propose);
const _swap = AccountAction(AccountActionKind.swap);
const _swapDisabled = AccountAction(AccountActionKind.swap, isEnabled: false);

void main() {
  test('a local account gets Receive, Send and Swap, all enabled', () {
    expect(accountActions(_local, swapAvailable: true, hasActiveSwap: false), [_receive, _send, _swap]);
  });

  test('where swaps are not offered, a local account gets no Swap', () {
    expect(accountActions(_local, swapAvailable: false, hasActiveSwap: false), [_receive, _send]);
  });

  test('a Keystone account gets Swap disabled', () {
    expect(accountActions(_keystone, swapAvailable: true, hasActiveSwap: false), [_receive, _send, _swapDisabled]);
  });

  test('the encrypted account gets Receive and Send, and Swap disabled', () {
    expect(accountActions(_encrypted, swapAvailable: true, hasActiveSwap: false), [_receive, _send, _swapDisabled]);
  });

  test('a multisig gets Receive and Propose, and no Send or Swap', () {
    expect(accountActions(_multisig, swapAvailable: true, hasActiveSwap: false), [_receive, _propose]);
  });

  test('an entrusted account gets no actions', () {
    expect(accountActions(_entrusted, swapAvailable: true, hasActiveSwap: false), isEmpty);
  });

  test('while a swap is running, every account type gets Swap enabled', () {
    expect(accountActions(_local, swapAvailable: false, hasActiveSwap: true), [_receive, _send, _swap]);
    expect(accountActions(_keystone, swapAvailable: true, hasActiveSwap: true), [_receive, _send, _swap]);
    expect(accountActions(_encrypted, swapAvailable: true, hasActiveSwap: true), [_receive, _send, _swap]);
    expect(accountActions(_multisig, swapAvailable: true, hasActiveSwap: true), [_receive, _propose, _swap]);
    expect(accountActions(_entrusted, swapAvailable: true, hasActiveSwap: true), [_swap]);
  });
}
