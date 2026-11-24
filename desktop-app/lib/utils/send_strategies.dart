import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/encrypted_send_strategy.dart';
import 'package:wallet_core/send/multisig_propose_strategy.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/utils/account_utils.dart';

/// The send this app can make from [active], or null where it cannot make
/// one: a private send from the Encrypted account, a transfer from a
/// transparent account whose key signs in the app or on a cold wallet, and a
/// multisig's proposal when the member of it in this wallet, one of
/// [accounts], signs in the app.
SendStrategy? sendStrategyFor(DisplayAccount? active, {required List<Account> accounts}) => switch (active) {
  RegularAccount(:final account) when isEncryptedAccount(account) => EncryptedSendStrategy(account: account),
  RegularAccount(:final account) when account.signsLocally || account.signsWithHardware => RegularSendStrategy(
    account: account,
  ),
  MultisigDisplayAccount(:final account) when _memberOf(account, accounts) != null => MultisigProposeStrategy(
    msig: account,
  ),
  _ => null,
};

/// The account among [accounts] that proposes for [multisig], when its key
/// signs in the app.
Account? _memberOf(MultisigAccount multisig, List<Account> accounts) =>
    accounts.where((account) => account.accountId == multisig.myMemberAccountId && account.signsLocally).firstOrNull;

/// The account that signs [strategy]'s send and pays what it costs, where
/// that is not the account the funds leave: the member who proposes for a
/// multisig. Null for a send its own account pays.
Account? sendSigner(SendStrategy strategy, List<Account> accounts) =>
    strategy is MultisigProposeStrategy ? _memberOf(strategy.msig, accounts) : null;

/// What this app calls the network's fee of [strategy]'s send.
String sendFeeLabel(SendStrategy strategy, AppLocalizations l10n) =>
    strategy is EncryptedSendStrategy ? l10n.desktopSendTransactionFee : l10n.swapReviewNetworkFee;
