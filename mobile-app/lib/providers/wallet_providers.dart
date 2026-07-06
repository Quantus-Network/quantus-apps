import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

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

final localeNumberConfigProvider = Provider<LocaleNumberConfig>((ref) {
  final appLocale = ref.watch(selectedAppLocaleProvider);
  return LocaleNumberConfig.fromLocale(appLocale.numberFormatLocale);
});

final numberFormattingServiceProvider = Provider<NumberFormattingService>((ref) {
  final localeConfig = ref.watch(localeNumberConfigProvider);

  return NumberFormattingService(localeConfig: localeConfig);
});

final humanReadableChecksumServiceProvider = Provider<HumanReadableChecksumService>((ref) {
  return HumanReadableChecksumService();
});

final checksumNameProvider = FutureProvider.family<String, String>((ref, address) {
  return ref.watch(humanReadableChecksumServiceProvider).getHumanReadableName(address);
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

/// One encrypted-account service per wallet: caches derived wormhole key pairs
/// and owns the persisted next-index / pending-spend state.
final encryptedAccountServiceProvider = Provider.family<EncryptedAccountService, int>((ref, walletIndex) {
  return EncryptedAccountService(
    walletIndex: walletIndex,
    getMnemonic: () => ref.read(settingsServiceProvider).getMnemonic(walletIndex),
  );
});

/// Discovered UTXO set + pending change for a wallet's encrypted account.
final encryptedStateProvider = FutureProvider.family<EncryptedAccountState, int>((ref, walletIndex) {
  return ref.watch(encryptedAccountServiceProvider(walletIndex)).load();
});

final encryptedBalanceProvider = Provider.family<AsyncValue<BigInt>, int>((ref, walletIndex) {
  return ref.watch(encryptedStateProvider(walletIndex)).whenData((s) => s.balance);
});

/// Exact max sendable (inputs net of the wormhole volume fee).
final encryptedSpendableProvider = Provider.family<AsyncValue<BigInt>, int>((ref, walletIndex) {
  return ref.watch(encryptedStateProvider(walletIndex)).whenData((s) => s.maxSendable);
});

bool isEncryptedAccount(BaseAccount? account) => account is Account && account.accountType == AccountType.encrypted;

/// Backfills the per-wallet encrypted (wormhole) account for every software
/// wallet, gated by the feature flag. Idempotent; returns true if any were
/// added (callers invalidate [accountsProvider] then).
Future<bool> ensureEncryptedAccounts(WidgetRef ref) async {
  if (!ref.read(remoteConfigProvider).enableEncryptedAccount) return false;
  final name = ref.read(l10nProvider).createAccountEncryptedDefaultName;
  return ref.read(accountsServiceProvider).ensureEncryptedAccountsForSoftwareWallets(name: name);
}

final isHighSecurityProvider = FutureProvider.family<bool, Account>((ref, account) async {
  final highSecurityService = ref.watch(highSecurityServiceProvider);
  return await highSecurityService.isHighSecurity(account);
});

final balanceProviderFamily = FutureProvider.family<BigInt, String>((ref, accountId) async {
  final substrateService = ref.watch(substrateServiceProvider);
  quantusDebugPrint('query balance for $accountId');
  return await substrateService.queryBalance(accountId);
});

/// Chain balance minus pending outgoing for any [accountId].
final effectiveBalanceProviderFamily = Provider.family<AsyncValue<BigInt>, String>((ref, accountId) {
  final balanceAsync = ref.watch(balanceProviderFamily(accountId));
  final pendingTransactions = ref.watch(pendingTransactionsProvider);
  final pendingMultisigProposals = ref.watch(pendingMultisigProposalsProvider);
  final pendingMultisigExecutions = ref.watch(pendingMultisigExecutionsProvider);
  final pendingMultisigCancellations = ref.watch(pendingMultisigCancellationsProvider);
  final pendingMultisigCreations = ref.watch(pendingMultisigCreationsProvider);

  return balanceAsync.when(
    data: (blockchainBalance) {
      final pendingOutgoing = _calculatePendingOutgoing(
        pendingTransactions,
        pendingMultisigProposals,
        pendingMultisigExecutions,
        pendingMultisigCancellations,
        pendingMultisigCreations,
        accountId,
      );
      final effectiveBalance = blockchainBalance - pendingOutgoing;
      final result = effectiveBalance >= BigInt.zero ? effectiveBalance : BigInt.zero;
      return AsyncValue.data(result);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

// Raw blockchain balance (without pending transaction adjustments)
final balanceProviderRaw = Provider<AsyncValue<BigInt>>((ref) {
  final activeAccountAsyncValue = ref.watch(activeAccountProvider);

  return activeAccountAsyncValue.when(
    data: (activeAccount) {
      if (activeAccount == null) {
        return AsyncValue.data(BigInt.zero);
      }
      final account = activeAccount.account;
      if (isEncryptedAccount(account)) {
        return ref.watch(encryptedBalanceProvider((account as Account).walletIndex));
      }
      return ref.watch(balanceProviderFamily(account.accountId));
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
  final pendingMultisigProposals = ref.watch(pendingMultisigProposalsProvider);
  final pendingMultisigExecutions = ref.watch(pendingMultisigExecutionsProvider);
  final pendingMultisigCancellations = ref.watch(pendingMultisigCancellationsProvider);
  final pendingMultisigCreations = ref.watch(pendingMultisigCreationsProvider);
  final activeAccountAsync = ref.watch(activeAccountProvider);

  return balanceAsync.when(
    data: (blockchainBalance) {
      final activeAccount = activeAccountAsync.value;
      if (activeAccount == null) {
        _cachedBalance = BigInt.zero;
        return AsyncValue.data(BigInt.zero);
      }

      final pendingOutgoing = _calculatePendingOutgoing(
        pendingTransactions,
        pendingMultisigProposals,
        pendingMultisigExecutions,
        pendingMultisigCancellations,
        pendingMultisigCreations,
        activeAccount.account.accountId,
      );
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
BigInt _calculatePendingOutgoing(
  List<PendingTransactionEvent> pendingTransactions,
  List<PendingMultisigProposalEvent> pendingMultisigProposals,
  List<PendingMultisigExecutionEvent> pendingMultisigExecutions,
  List<PendingMultisigCancellationEvent> pendingMultisigCancellations,
  List<PendingMultisigCreationEvent> pendingMultisigCreations,
  String accountId,
) {
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

  for (final proposal in pendingMultisigProposals) {
    if (proposal.proposerId == accountId) {
      totalOutgoing += proposal.memberCost;
    }
  }

  for (final execution in pendingMultisigExecutions) {
    if (execution.executorId == accountId) {
      totalOutgoing += execution.memberCost;
    }
  }

  for (final cancellation in pendingMultisigCancellations) {
    if (cancellation.proposerId == accountId) {
      totalOutgoing += cancellation.memberCost;
    }
  }

  for (final creation in pendingMultisigCreations) {
    if (creation.creatorId == accountId) {
      totalOutgoing += creation.totalCost;
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

final recoveryPhraseViewedProvider = Provider.family<bool, int>((ref, walletIndex) {
  return ref.watch(settingsServiceProvider).recoveryPhraseViewed(walletIndex);
});

final walletOriginProvider = Provider.family<WalletOrigin?, int>((ref, walletIndex) {
  return ref.watch(settingsServiceProvider).getWalletOrigin(walletIndex);
});

/// 0.0001 QUAN in raw units; dust below this doesn't warrant a backup nudge.
final _backupNudgeBalanceThreshold = BigInt.from(10).pow(AppConstants.decimals - 4);

/// Wallet index needing a recovery phrase backup reminder, or null when none.
/// Only nudges mnemonic-backed wallets created on this device (or legacy wallets
/// of unknown origin). Never nudges multisig/entrusted accounts (not
/// [RegularAccount]), hardware (keystone) wallets, or imported wallets.
final backupReminderWalletIndexProvider = Provider<int?>((ref) {
  final active = ref.watch(activeAccountProvider).value;
  if (active is! RegularAccount) return null;
  if (active.account.accountType != AccountType.local) return null;

  final walletIndex = active.account.walletIndex;
  if (AppConstants.debugAlwaysShowBackupNudge) return walletIndex;

  if (ref.watch(walletOriginProvider(walletIndex)) == WalletOrigin.imported) return null;
  if (ref.watch(recoveryPhraseViewedProvider(walletIndex))) return null;

  final balance = ref.watch(balanceProvider).value ?? BigInt.zero;
  return balance > _backupNudgeBalanceThreshold ? walletIndex : null;
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
