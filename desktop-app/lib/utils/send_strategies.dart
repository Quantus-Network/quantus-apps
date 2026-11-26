import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/encrypted_send_strategy.dart';
import 'package:wallet_core/send/multisig_propose_strategy.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/utils/account_utils.dart';
import 'package:wallet_core/utils/multisig_local_signers.dart';

/// The send this app can make from [active], or null where it cannot make
/// one: a private send from the Encrypted account, a transfer from a
/// transparent account whose key signs in the app or on a cold wallet, and a
/// multisig's proposal when one of its signers among [accounts] signs in the
/// app or on a cold wallet. The first of [proposersFor] proposes.
SendStrategy? sendStrategyFor(DisplayAccount? active, {required List<Account> accounts}) => switch (active) {
  RegularAccount(:final account) when isEncryptedAccount(account) => EncryptedSendStrategy(account: account),
  RegularAccount(:final account) when _signsHere(account) => RegularSendStrategy(account: account),
  MultisigDisplayAccount(:final account) => switch (proposersFor(account, accounts).firstOrNull) {
    final proposer? => MultisigProposeStrategy(msig: account, proposerId: proposer.accountId),
    null => null,
  },
  _ => null,
};

/// The accounts among [accounts] that can propose for [multisig]: its
/// signers whose key signs in the app or on a cold wallet, the multisig's
/// member first, then the others in [accounts]' order.
List<Account> proposersFor(MultisigAccount multisig, List<Account> accounts) {
  final signers = localSignersForMultisig(multisig, accounts).where(_signsHere);
  return [
    ...signers.where((account) => account.accountId == multisig.myMemberAccountId),
    ...signers.where((account) => account.accountId != multisig.myMemberAccountId),
  ];
}

bool _signsHere(Account account) => account.signsLocally || account.signsWithHardware;

/// The account that signs [strategy]'s send and pays what it costs, where
/// that is not the account the funds leave: the signer who proposes for a
/// multisig, one of [accounts]. Null for a send its own account pays.
Account? sendSigner(SendStrategy strategy, List<Account> accounts) => switch (strategy) {
  MultisigProposeStrategy(:final proposerId) =>
    accounts.where((account) => account.accountId == proposerId).firstOrNull ??
        (throw StateError('The account proposing, $proposerId, is not in this wallet.')),
  _ => null,
};

/// What this app calls the network's fee of [strategy]'s send.
String sendFeeLabel(SendStrategy strategy, AppLocalizations l10n) =>
    strategy is EncryptedSendStrategy ? l10n.desktopSendTransactionFee : l10n.swapReviewNetworkFee;
