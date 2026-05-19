import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final accountsServiceProvider = Provider<AccountsService>((ref) {
  return AccountsService();
});

final chainHistoryServiceProvider = Provider<ChainHistoryService>((ref) {
  return ChainHistoryService();
});

final substrateServiceProvider = Provider<SubstrateService>((ref) {
  return SubstrateService();
});

final recentAddressesServiceProvider = Provider<RecentAddressesService>((ref) {
  return RecentAddressesService();
});

/// Caveat: snapshots [Platform.localeName] at provider creation time.
/// A mid-session locale change (rare) won't be picked up until app restart.
final localeNumberConfigProvider = Provider<LocaleNumberConfig>((ref) {
  return LocaleNumberConfig.fromLocale(Platform.localeName);
});

final numberFormattingServiceProvider = Provider<NumberFormattingService>((ref) {
  final localeConfig = ref.watch(localeNumberConfigProvider);

  return NumberFormattingService(localeConfig: localeConfig);
});

final humanReadableChecksumServiceProvider = Provider<HumanReadableChecksumService>((ref) {
  return HumanReadableChecksumService();
});

final reversibleTransfersServiceProvider = Provider<ReversibleTransfersService>((ref) {
  return ReversibleTransfersService();
});

final balancesServiceProvider = Provider<BalancesService>((ref) {
  return BalancesService();
});

final highSecurityServiceProvider = Provider<HighSecurityService>((ref) {
  return HighSecurityService();
});

final hdWalletServiceProvider = Provider<HdWalletService>((ref) {
  return HdWalletService();
});

final wormholeUtxoServiceProvider = Provider<WormholeUtxoService>((ref) {
  return WormholeUtxoService();
});

final isHighSecurityProvider = FutureProvider.family<bool, Account>((ref, account) async {
  final highSecurityService = ref.watch(highSecurityServiceProvider);
  return await highSecurityService.isHighSecurity(account);
});

final balanceProviderFamily = FutureProvider.family<BigInt, String>((ref, accountId) async {
  final substrateService = ref.watch(substrateServiceProvider);
  print('query balance for $accountId');
  return await substrateService.queryBalance(accountId);
});

// Raw blockchain balance (without pending transaction adjustments)
final balanceProviderRaw = Provider<AsyncValue<BigInt>>((ref) {
  final activeAccountAsyncValue = ref.watch(activeAccountProvider);

  return activeAccountAsyncValue.when(
    data: (activeAccount) {
      if (activeAccount == null) {
        return AsyncValue.data(BigInt.zero);
      }
      return ref.watch(balanceProviderFamily(activeAccount.account.accountId));
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

// Store for cached balance to return on error
BigInt _cachedBalance = BigInt.zero;

// Effective balance (blockchain balance minus pending outgoing transactions)
final balanceProvider = Provider<AsyncValue<BigInt>>((ref) {
  final balanceAsync = ref.watch(balanceProviderRaw);
  final pendingTransactions = ref.watch(pendingTransactionsProvider);
  final activeAccountAsync = ref.watch(activeAccountProvider);

  return balanceAsync.when(
    data: (blockchainBalance) {
      final activeAccount = activeAccountAsync.value;
      if (activeAccount == null) {
        _cachedBalance = BigInt.zero;
        return AsyncValue.data(BigInt.zero);
      }

      final pendingOutgoing = _calculatePendingOutgoing(pendingTransactions, activeAccount.account.accountId);
      final effectiveBalance = blockchainBalance - pendingOutgoing;
      final result = effectiveBalance >= BigInt.zero ? effectiveBalance : BigInt.zero;
      _cachedBalance = result;
      return AsyncValue.data(result);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) {
      // On error, return last cached balance
      return AsyncValue.data(_cachedBalance);
    },
  );
});

/// Calculates the total amount of pending outgoing transactions for a
/// specific account
BigInt _calculatePendingOutgoing(List<PendingTransactionEvent> pendingTransactions, String accountId) {
  BigInt totalOutgoing = BigInt.zero;

  for (final transaction in pendingTransactions) {
    // Only count outgoing transactions (where this account is the sender)
    if (transaction.from == accountId) {
      totalOutgoing += transaction.amount;

      // Add fee if available (for more accurate available balance)
      if (transaction.fee != null) {
        totalOutgoing += transaction.fee!;
      }
    }
  }

  return totalOutgoing;
}

// fetch high security config
final highSecurityConfigProvider = FutureProvider.family<HighSecurityData?, BaseAccount?>((ref, account) async {
  if (account == null) {
    return null;
  }
  final service = ref.read(highSecurityServiceProvider);
  return service.getHighSecurityConfig(account.accountId);
});

final highSecurityEstimatedFeeProvider = FutureProvider.family<BigInt, Account>((ref, account) async {
  final highSecurityService = ref.read(highSecurityServiceProvider);
  // Invent fake parameters for estimation
  final feeData = await highSecurityService.getHighSecuritySetupFee(
    account,
    account.accountId, // Use self as dummy guardian
    const Duration(days: 14), // Fake duration
  );
  return feeData.fee;
});

final isBalanceHiddenProvider = StateNotifierProvider<IsBalanceHiddenNotifier, bool>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return IsBalanceHiddenNotifier(settingsService);
});

class IsBalanceHiddenNotifier extends StateNotifier<bool> {
  final SettingsService _settingsService;

  IsBalanceHiddenNotifier(this._settingsService) : super(_settingsService.isBalanceHidden());

  Future<void> setIsBalanceHidden(bool value) async {
    await _settingsService.setBalanceHidden(value);
    state = value;
  }
}

final posModeProvider = StateNotifierProvider<PosModeNotifier, bool>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return PosModeNotifier(settingsService);
});

class PosModeNotifier extends StateNotifier<bool> {
  final SettingsService _settingsService;

  PosModeNotifier(this._settingsService) : super(_settingsService.isPosModeEnabled());

  Future<void> setPosMode(bool value) async {
    await _settingsService.setPosModeEnabled(value);
    state = value;
  }
}
