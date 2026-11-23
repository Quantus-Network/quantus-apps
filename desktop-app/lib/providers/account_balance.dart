import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// [account]'s balance in the chain's smallest unit, watched. The encrypted
/// account's balance comes from its own notes, not from the chain's balance
/// of its address.
AsyncValue<BigInt> watchAccountBalance(WidgetRef ref, BaseAccount account) => accountBalanceWith(ref.watch, account);

/// [account]'s balance as [watchAccountBalance] gives it, watched with
/// [watch], so a provider can follow it as well as a widget.
AsyncValue<BigInt> accountBalanceWith(ProviderReader watch, BaseAccount account) {
  return account is Account && isEncryptedAccount(account)
      ? watch(encryptedBalanceProvider(account.walletIndex))
      : watch(balanceProviderFamily(account.accountId));
}
