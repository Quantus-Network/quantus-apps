import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swap_provider.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/mining_rewards_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/multisig_approval_polling_service.dart';
import 'package:wallet_core/services/multisig_cancellation_polling_service.dart';
import 'package:wallet_core/services/multisig_creation_polling_service.dart';
import 'package:wallet_core/services/multisig_execution_polling_service.dart';
import 'package:wallet_core/services/multisig_proposal_polling_service.dart';
import 'package:wallet_core/services/pending_transaction_polling_service.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/services/push_registration.dart';

final logoutServiceProvider = Provider<LogoutService>((ref) => LogoutService(ref));

class LogoutService {
  final Ref _ref;
  LogoutService(this._ref);

  /// Wipes the wallet and every piece of session state. Where to go next is
  /// the caller's decision.
  Future<void> logout() async {
    if (_ref.read(remoteConfigProvider).enableRemoteNotifications) {
      _ref.read(pushRegistrationProvider).unregister();
    }

    // Before the wipe: a status answer still in flight must not write the
    // old wallet's swap back, and nothing of it may reach the next session.
    await _ref.read(activeSwapProvider.notifier).clear();
    await _ref.read(substrateServiceProvider).logout();
    _stopPollers();
    _ref.read(pendingTransactionsProvider.notifier).clear();
    await _ref.read(pendingMultisigCreationsProvider.notifier).clear();
    _ref.read(pendingMultisigProposalsProvider.notifier).clear();
    _ref.read(pendingMultisigApprovalsProvider.notifier).clear();
    _ref.read(pendingMultisigExecutionsProvider.notifier).clear();
    _ref.read(pendingMultisigCancellationsProvider.notifier).clear();
    _ref.read(accountsProvider.notifier).reset();
    _ref.read(activeAccountProvider.notifier).reset();
    _ref.invalidate(recoveryPhraseViewedProvider);
    _ref.invalidate(airdropClaimRecordProvider);
    _ref.invalidate(walletOriginProvider);
    // Drop encrypted-account Riverpod state so the next session doesn't show
    // the previous wallet's balance while disk caches are already wiped above.
    _ref.invalidate(encryptedAccountServiceProvider);
    _ref.invalidate(encryptedStateProvider);
    _ref.invalidate(encryptedBalanceProvider);
    _ref.invalidate(encryptedSpendableProvider);
    _ref.invalidate(encryptedHistoryProvider);
    _ref.read(multisigAccountsProvider.notifier).reset();
    _ref.invalidate(discoveredMultisigsProvider);
    _ref.read(keystoneSignCacheProvider.notifier).reset();
    await _ref.read(selectedAppLocaleProvider.notifier).reset();
    await _ref.read(selectedFiatCurrencyProvider.notifier).reset();
  }

  /// Stops indexer pollers so their timers cannot leak into the next session.
  void _stopPollers() {
    _ref.read(pendingTransactionPollingServiceProvider).stopAll();
    _ref.read(multisigCreationPollingServiceProvider).stopAll();
    _ref.read(multisigProposalPollingServiceProvider).stopAll();
    _ref.read(multisigApprovalPollingServiceProvider).stopAll();
    _ref.read(multisigExecutionPollingServiceProvider).stopAll();
    _ref.read(multisigCancellationPollingServiceProvider).stopAll();
  }
}
