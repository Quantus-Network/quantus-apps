import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// Re-fetches the current account's balance once per block while the app is
/// visible. Read once from the shell so the timer lives with it.
final balanceRefreshTickerProvider = Provider<void>((ref) {
  final timer = Timer.periodic(const Duration(seconds: AppConstants.avgBlockTimeSeconds), (_) {
    final account = ref.read(currentAccountProvider);
    if (account != null) ref.invalidate(balanceProviderFamily(account.accountId));
  });
  ref.onDispose(timer.cancel);
});

/// The current account's chain balance.
final currentBalanceProvider = Provider<AsyncValue<BigInt>>((ref) {
  final account = ref.watch(currentAccountProvider);
  if (account == null) return const AsyncValue.loading();
  return ref.watch(balanceProviderFamily(account.accountId));
});

/// Chain balance minus what pending outgoing transfers will take; what the
/// user can still send.
final spendableBalanceProvider = Provider<AsyncValue<BigInt>>((ref) {
  final account = ref.watch(currentAccountProvider);
  final balance = ref.watch(currentBalanceProvider);
  if (account == null) return balance;
  final pending = ref.watch(pendingTransactionsProvider);
  var outgoing = BigInt.zero;
  for (final tx in pending) {
    if (tx.from == account.accountId) outgoing += tx.amount + (tx.fee ?? BigInt.zero);
  }
  return balance.whenData((value) {
    final spendable = value - outgoing;
    return spendable < BigInt.zero ? BigInt.zero : spendable;
  });
});

/// Balance with the fiat conversion, for the balance headers.
final balanceDisplayProvider = Provider<AsyncValue<CurrencyDisplayState>>((ref) {
  final balance = ref.watch(currentBalanceProvider);
  final fiat = ref.watch(selectedFiatCurrencyProvider);
  final rates = ref.watch(exchangeRateServiceProvider);
  final formatter = ref.watch(numberFormattingServiceProvider);
  final localeConfig = ref.watch(localeNumberConfigProvider);
  return balance.whenData(
    (value) => CurrencyDisplayState.format(
      value,
      selectedFiat: fiat,
      formatter: formatter,
      localeConfig: localeConfig,
      tokenDecimals: 4,
      withTokenSymbol: false,
      fiatRate: rates,
    ),
  );
});
