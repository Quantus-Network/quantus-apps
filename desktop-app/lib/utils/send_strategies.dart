import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/encrypted_send_strategy.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/utils/account_utils.dart';

/// The send this app can make from [active], or null where it cannot make
/// one: so far a private send from the Encrypted account, and a transfer
/// from a transparent account whose key signs in the app. A multisig's
/// proposal is to come.
SendStrategy? sendStrategyFor(DisplayAccount? active) => switch (active) {
  RegularAccount(:final account) when isEncryptedAccount(account) => EncryptedSendStrategy(account: account),
  RegularAccount(:final account) when account.signsLocally => RegularSendStrategy(account: account),
  _ => null,
};

/// What this app calls the fee of [strategy]'s send.
String sendFeeLabel(SendStrategy strategy, AppLocalizations l10n) =>
    strategy is EncryptedSendStrategy ? l10n.desktopSendTransactionFee : l10n.swapReviewNetworkFee;
