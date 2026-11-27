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

/// The sum of [accounts]' balances, watched with [watch], as [totalOf] adds
/// them up.
AsyncValue<BigInt> accountsTotalWith(ProviderReader watch, Iterable<BaseAccount> accounts) =>
    totalOf([for (final account in accounts) accountBalanceWith(watch, account)]);

/// The sum of [balances]. It fails when any of them failed, as the sum cannot
/// be right without it, and is loading while any is still loading. Each is
/// read as a row reads its balance, so one being refreshed counts with the
/// value it had.
AsyncValue<BigInt> totalOf(Iterable<AsyncValue<BigInt>> balances) {
  var total = BigInt.zero;
  var loading = false;
  for (final balance in balances) {
    final failure = balance.when(
      data: (value) {
        total += value;
        return null;
      },
      error: (error, stackTrace) => AsyncValue<BigInt>.error(error, stackTrace),
      loading: () {
        loading = true;
        return null;
      },
    );
    if (failure != null) return failure;
  }
  return loading ? const AsyncValue.loading() : AsyncValue.data(total);
}
