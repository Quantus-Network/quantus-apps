import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/utils/account_utils.dart';

/// The send this app can make from [active], or null where it cannot make
/// one: so far a transfer from a transparent account whose key signs in the
/// app. The Encrypted account's send and a multisig's proposal are to come.
SendStrategy? sendStrategyFor(DisplayAccount? active) => switch (active) {
  RegularAccount(:final account) when account.signsLocally => RegularSendStrategy(account: account),
  _ => null,
};
