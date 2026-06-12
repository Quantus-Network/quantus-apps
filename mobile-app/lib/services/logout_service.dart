import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/multisig_approval_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_cancellation_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_creation_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_execution_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_proposal_polling_service.dart';
import 'package:resonance_network_wallet/services/pending_transaction_polling_service.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';

final logoutServiceProvider = Provider<LogoutService>((ref) => LogoutService(ref));

class LogoutService {
  final Ref _ref;
  LogoutService(this._ref);

  Future<void> logout(BuildContext context) async {
    if (_ref.read(remoteConfigProvider).enableRemoteNotifications) {
      _ref.read(firebaseMessagingServiceProvider).unregisterDevice();
    }

    await SubstrateService().logout();
    _stopPollers();
    _ref.read(pendingTransactionsProvider.notifier).clear();
    await _ref.read(pendingMultisigCreationsProvider.notifier).clear();
    _ref.read(pendingMultisigProposalsProvider.notifier).clear();
    _ref.read(pendingMultisigApprovalsProvider.notifier).clear();
    _ref.read(pendingMultisigExecutionsProvider.notifier).clear();
    _ref.read(pendingMultisigCancellationsProvider.notifier).clear();
    _ref.read(miningRewardsServiceProvider).clearCachedRewardsData();
    _ref.invalidate(miningRewardsProvider);
    _ref.read(accountsProvider.notifier).reset();
    _ref.read(activeAccountProvider.notifier).reset();
    _ref.read(multisigAccountsProvider.notifier).reset();
    _ref.invalidate(discoveredMultisigsProvider);
    _ref.read(accountAssociationsProvider.notifier).reset();
    await _ref.read(selectedAppLocaleProvider.notifier).reset();
    await _ref.read(selectedFiatCurrencyProvider.notifier).reset();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreenV2()), (r) => false);
    }
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
