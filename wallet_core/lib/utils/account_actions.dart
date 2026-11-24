import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/account_utils.dart';

enum AccountActionKind { receive, send, propose, swap }

/// One action offered on an account. A disabled action is shown but cannot be
/// used, so the row of actions keeps its shape from one account to the next.
@immutable
class AccountAction {
  final AccountActionKind kind;
  final bool isEnabled;

  const AccountAction(this.kind, {this.isEnabled = true});

  @override
  bool operator ==(Object other) => other is AccountAction && other.kind == kind && other.isEnabled == isEnabled;

  @override
  int get hashCode => Object.hash(kind, isEnabled);

  @override
  String toString() => 'AccountAction(${kind.name}, isEnabled: $isEnabled)';
}

/// The actions offered on [active], in display order.
///
/// A regular account receives and sends; a multisig receives and proposes; an
/// entrusted account does neither. Swap is offered on regular accounts where
/// swaps are available, and is disabled unless the account's key signs in
/// this app.
List<AccountAction> accountActions(DisplayAccount active, {required bool swapAvailable}) {
  return [
    ...switch (active) {
      RegularAccount() => const [AccountAction(AccountActionKind.receive), AccountAction(AccountActionKind.send)],
      MultisigDisplayAccount() => const [
        AccountAction(AccountActionKind.receive),
        AccountAction(AccountActionKind.propose),
      ],
      EntrustedDisplayAccount() => const <AccountAction>[],
    },
    if (active is RegularAccount && swapAvailable)
      AccountAction(AccountActionKind.swap, isEnabled: active.account.signsLocally),
  ];
}
