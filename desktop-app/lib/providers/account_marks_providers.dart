import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/chain_status_providers.dart';
import 'package:quantus_desktop_wallet/providers/sync_status_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_progress.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/filtered_all_transactions_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/transaction_service.dart';
import 'package:wallet_core/utils/multisig_local_signers.dart';

/// What of an account needs a look: how many of its transfers are in
/// progress, as its In progress panel would list them; and, for a multisig,
/// how many of its open proposals wait for a signature from this wallet.
@immutable
class AccountMark {
  const AccountMark({this.inProgress = 0, this.waitingForSignature = 0});

  final int inProgress;
  final int waitingForSignature;

  /// The two together, as the account's badge shows them.
  int get count => inProgress + waitingForSignature;

  @override
  bool operator ==(Object other) =>
      other is AccountMark && other.inProgress == inProgress && other.waitingForSignature == waitingForSignature;

  @override
  int get hashCode => Object.hash(inProgress, waitingForSignature);

  @override
  String toString() => 'AccountMark(inProgress: $inProgress, waitingForSignature: $waitingForSignature)';
}

/// What is still scheduled to or from any of the wallet's accounts and
/// multisigs, read in one request each time the wallet syncs, from its first
/// sync on: until then, nothing is known to be. The Encrypted account has no
/// address of its own for a transfer to be scheduled at.
final stillScheduledTransfersProvider = FutureProvider<List<ReversibleTransferEvent>>((ref) {
  final syncedAt = ref.watch(syncStatusProvider.select((status) => status.lastSyncedAt));
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final multisigs = ref.watch(multisigAccountsProvider).value ?? const <MultisigAccount>[];
  final ids = [
    for (final account in accounts)
      if (!isEncryptedAccount(account)) account.accountId,
    for (final multisig in multisigs) multisig.accountId,
  ];
  if (syncedAt == null || ids.isEmpty) return const [];
  return ref.read(chainHistoryServiceProvider).fetchStillScheduledTransfers(accountIds: ids);
});

/// Each of the wallet's accounts and multisigs' [AccountMark], by its id.
///
/// What is in progress is counted as the account's panels list it: what it
/// has pending, with what is still scheduled to or from it; the Encrypted
/// account's, from what its last scan holds. A multisig's open proposals are
/// read again each time the wallet syncs; one waits for this wallet's
/// signature while it is active, not expired (at the latest block, when that
/// is known) and one of its signers here has neither approved it nor an
/// approval on its way.
final accountMarksProvider = Provider<Map<String, AccountMark>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final multisigs = ref.watch(multisigAccountsProvider).value ?? const <MultisigAccount>[];
  ref.listen(syncStatusProvider.select((status) => status.lastSyncedAt), (_, _) {
    for (final multisig in multisigs) {
      ref.invalidate(multisigOpenProposalsProvider(multisig));
    }
  });
  final pending = ref.watch(pendingActivityProvider);
  final scheduled = ref.watch(stillScheduledTransfersProvider).value ?? const <ReversibleTransferEvent>[];
  final approvals = ref.watch(pendingMultisigApprovalsProvider);
  final block = ref.watch(latestBlockProvider);
  final service = ref.read(transactionServiceProvider);

  int inProgressOf(BaseAccount account) {
    final CombinedTransactionsList data;
    if (account is Account && isEncryptedAccount(account)) {
      final history = ref.watch(encryptedHistoryProvider(account.walletIndex)).value ?? const <TransactionEvent>[];
      data = CombinedTransactionsList.empty.copyWith(otherTransfers: [...history]);
    } else {
      final id = account.accountId;
      data = combinedTransactionsOf(
        pending,
        accountIds: [id],
        filter: TransactionFilter.all,
        scheduledReversibleTransfers: [
          for (final transfer in scheduled)
            if (transfer.from == id || transfer.to == id) transfer,
        ],
        otherTransfers: [],
      );
    }
    // The lists the transfers go in are the combiner's own to add to and
    // sort: it moves a send that failed among the settled ones.
    return partActivityByProgress(activityOf(service, account, data, const [])).inProgress.length;
  }

  int waitingOf(MultisigAccount multisig) {
    final open = ref.watch(multisigOpenProposalsProvider(multisig)).value ?? const <MultisigProposal>[];
    final signerIds = localSignersForMultisig(multisig, accounts).map((signer) => signer.accountId);
    return open.where((proposal) {
      if (proposal.status != MultisigProposalStatus.active) return false;
      if (block != null && proposal.expired(block)) return false;
      final approving = pendingApproverIdsForProposal(approvals, multisig.accountId, proposal.id, signerIds);
      return eligibleApproversForProposal(multisig, proposal, accounts, pendingApproverIds: approving).isNotEmpty;
    }).length;
  }

  return {
    for (final account in accounts) account.accountId: AccountMark(inProgress: inProgressOf(account)),
    for (final multisig in multisigs)
      multisig.accountId: AccountMark(inProgress: inProgressOf(multisig), waitingForSignature: waitingOf(multisig)),
  };
});
