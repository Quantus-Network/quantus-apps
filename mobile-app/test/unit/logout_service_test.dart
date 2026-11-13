import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/extrinsic_indexer_polling_service.dart';
import 'package:resonance_network_wallet/services/logout_service.dart';
import 'package:resonance_network_wallet/services/multisig_approval_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_cancellation_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_creation_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_execution_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_proposal_polling_service.dart';
import 'package:resonance_network_wallet/services/pending_transaction_polling_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

mixin _StopRecorder {
  int stopAllCalls = 0;

  void stopAll() => stopAllCalls++;
}

class _PendingTransactionPoller extends Fake with _StopRecorder implements PendingTransactionPollingService {}

class _MultisigCreationPoller extends Fake with _StopRecorder implements MultisigCreationPollingService {}

class _IndexerPoller<TPending> extends Fake
    with _StopRecorder
    implements ExtrinsicIndexerPollingService<TPending, MultisigAccount> {}

void main() {
  late FakePushRegistration push;
  late FakeSubstrateService substrate;
  late List<_StopRecorder> pollers;

  ProviderContainer containerWith({required bool remoteNotifications}) {
    final pendingTransactions = _PendingTransactionPoller();
    final creations = _MultisigCreationPoller();
    final proposals = _IndexerPoller<PendingMultisigProposalEvent>();
    final approvals = _IndexerPoller<PendingMultisigApprovalEvent>();
    final executions = _IndexerPoller<PendingMultisigExecutionEvent>();
    final cancellations = _IndexerPoller<PendingMultisigCancellationEvent>();
    pollers = [pendingTransactions, creations, proposals, approvals, executions, cancellations];

    final container = ProviderContainer(
      overrides: [
        ...testWalletCoreOverrides(pushRegistration: push),
        remoteConfigServiceProvider.overrideWithValue(
          FakeRemoteConfigService(RemoteConfigModel.fromJson({'enableRemoteNotifications': remoteNotifications})),
        ),
        settingsServiceProvider.overrideWithValue(FakeSettingsService(multisigs: [makeMultisigAccount()])),
        substrateServiceProvider.overrideWithValue(substrate),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: [makeAccount(0)])),
        pendingTransactionPollingServiceProvider.overrideWithValue(pendingTransactions),
        multisigCreationPollingServiceProvider.overrideWithValue(creations),
        multisigProposalPollingServiceProvider.overrideWithValue(proposals),
        multisigApprovalPollingServiceProvider.overrideWithValue(approvals),
        multisigExecutionPollingServiceProvider.overrideWithValue(executions),
        multisigCancellationPollingServiceProvider.overrideWithValue(cancellations),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    push = FakePushRegistration();
    substrate = FakeSubstrateService();
  });

  group('LogoutService.logout', () {
    test('wipes storage, clears pending state, stops pollers and unregisters push', () async {
      final container = containerWith(remoteNotifications: true);
      container
          .read(pendingTransactionsProvider.notifier)
          .add(
            PendingTransactionEvent(
              tempId: 'tx-1',
              from: makeAccount(0).accountId,
              to: makeAccount(1).accountId,
              amount: BigInt.one,
              timestamp: DateTime(2026),
              transactionState: TransactionState.pending,
              isReversible: false,
              fee: BigInt.zero,
            ),
          );
      container.read(multisigAccountsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(pendingTransactionsProvider), hasLength(1));
      expect(container.read(multisigAccountsProvider).value, hasLength(1));

      await container.read(logoutServiceProvider).logout();

      expect(substrate.logoutCalls, 1);
      expect(push.calls, ['unregister']);
      expect(pollers.map((poller) => poller.stopAllCalls), everyElement(1));
      expect(container.read(pendingTransactionsProvider), isEmpty);
      expect(container.read(multisigAccountsProvider).value, isEmpty);
      expect(container.read(accountsProvider).isLoading, isTrue);
    });

    test('leaves push alone when remote notifications are disabled', () async {
      final container = containerWith(remoteNotifications: false);

      await container.read(logoutServiceProvider).logout();

      expect(substrate.logoutCalls, 1);
      expect(push.calls, isEmpty);
    });
  });
}
