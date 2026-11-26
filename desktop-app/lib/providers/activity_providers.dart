import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_progress.dart';
import 'package:wallet_core/activity/multisig_activity.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/active_account_transactions_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/services/transaction_service.dart';

/// How wide the panel at the right that shows one transaction or proposal
/// is, in points: what the person dragged it to, kept for the next start.
final inspectorWidthProvider = NotifierProvider<InspectorWidthNotifier, double>(InspectorWidthNotifier.new);

class InspectorWidthNotifier extends SavedWidthNotifier {
  static const double initial = 380;
  static const double minimum = 360;
  static const double maximum = 480;

  /// Where the width is kept between runs.
  static const settingsKey = 'desktop_inspector_width';

  @override
  double get startWidth => initial;

  @override
  double get minWidth => minimum;

  @override
  double get maxWidth => maximum;

  @override
  String get key => settingsKey;

  @override
  String get panelName => 'transaction panel';
}

/// Whether a refresh the person asked for (↻, or View › Refresh) is running.
/// Refreshes the polling starts on its own are not counted.
final walletRefreshingProvider = NotifierProvider<WalletRefreshingNotifier, bool>(WalletRefreshingNotifier.new);

class WalletRefreshingNotifier extends Notifier<bool> {
  int _running = 0;

  @override
  bool build() => false;

  /// Notes that [refresh] runs, until it ends, however it ends.
  Future<void> track(Future<void> refresh) async {
    _running++;
    state = true;
    try {
      await refresh;
    } finally {
      _running--;
      state = _running > 0;
    }
  }
}

/// What the panel at the window's right shows: a transaction, a proposal, or
/// a swap being followed.
sealed class OpenedActivity {
  const OpenedActivity();

  /// What the lists know it by.
  String get id;
}

final class OpenedTransaction extends OpenedActivity {
  const OpenedTransaction(this.tx);

  final TransactionEvent tx;

  @override
  String get id => tx.id;

  @override
  bool operator ==(Object other) => other is OpenedTransaction && other.tx.id == tx.id;

  @override
  int get hashCode => tx.id.hashCode;
}

final class OpenedProposal extends OpenedActivity {
  const OpenedProposal(this.proposal);

  final MultisigProposal proposal;

  @override
  String get id => proposal.entityId;

  @override
  bool operator ==(Object other) => other is OpenedProposal && other.proposal.entityId == proposal.entityId;

  @override
  int get hashCode => proposal.entityId.hashCode;
}

/// What is open in the panel at the window's right, if anything. It closes
/// when another account is shown.
final openedActivityProvider = NotifierProvider<OpenedActivityNotifier, OpenedActivity?>(OpenedActivityNotifier.new);

class OpenedActivityNotifier extends Notifier<OpenedActivity?> {
  @override
  OpenedActivity? build() {
    ref.listen(activeAccountProvider.select((active) => active.value?.account.accountId), (previous, next) {
      if (previous != next) state = null;
    });
    // A proposal opened while it was being sent learns the hash it went out
    // in, by which it is followed once the network has created it.
    ref.listen(pendingMultisigProposalsProvider, (_, proposing) {
      if (state case OpenedTransaction(tx: final PendingMultisigProposalEvent opened)) {
        final now = proposing.where((pending) => pending.id == opened.id).firstOrNull;
        if (now != null && now.extrinsicHash != opened.extrinsicHash) state = OpenedTransaction(now);
      }
    });
    return null;
  }

  void open(OpenedActivity activity) => state = activity;

  void close() => state = null;
}

/// The open account's activity, as its panels list it: what is still in
/// progress, in the phone's order, and what is settled, newest first.
@immutable
class ActivityView {
  const ActivityView({
    required this.inProgress,
    required this.settled,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isReloading = false,
    this.reloadFailure,
  });

  final List<TransactionEvent> inProgress;
  final List<TransactionEvent> settled;

  /// Whether older activity is still to be fetched, and whether it is being
  /// fetched now.
  final bool hasMore;
  final bool isLoadingMore;

  /// Whether these are the rows last shown, kept on screen while the
  /// account's history loads again from nothing.
  final bool isReloading;

  /// Why that reload failed, while the rows last shown stay on screen.
  final Object? reloadFailure;

  /// These rows, kept while the history reloads, or after the reload failed
  /// with [failure]. No older page is asked for meanwhile: the history is
  /// starting over.
  ActivityView _kept({Object? failure}) =>
      ActivityView(inProgress: inProgress, settled: settled, isReloading: failure == null, reloadFailure: failure);
}

/// The open account's activity. A multisig's is its past proposals and what
/// it received; its open proposals are [openProposalsViewProvider]'s.
///
/// Once an account's rows have been shown, a reload of its history from
/// nothing (a refresh asked for, or the accounts changing) keeps them on
/// screen until the new ones arrive, and a reload that fails keeps them with
/// why. Another account's rows are never kept for it.
final activityViewProvider = NotifierProvider<ActivityViewNotifier, AsyncValue<ActivityView>>(ActivityViewNotifier.new);

class ActivityViewNotifier extends Notifier<AsyncValue<ActivityView>> {
  /// The rows last shown, and whose they are.
  ({String accountId, ActivityView view})? _shown;

  @override
  AsyncValue<ActivityView> build() {
    final active = ref.watch(activeAccountProvider);
    final account = active.value?.account;
    if (account == null) {
      return active.isLoading
          ? const AsyncValue.loading()
          : const AsyncValue.data(ActivityView(inProgress: [], settled: []));
    }
    final next = _activityOf(account);
    if (next case AsyncData(:final value)) {
      _shown = (accountId: account.accountId, view: value);
      return next;
    }
    final shown = _shown;
    if (shown == null || shown.accountId != account.accountId) return next;
    return AsyncData(next.hasError ? shown.view._kept(failure: next.error) : shown.view._kept());
  }

  AsyncValue<ActivityView> _activityOf(BaseAccount account) {
    final transactions = ref.watch(activeAccountTransactionsProvider(TransactionFilter.all));
    final pages = ref.watch(activeAccountPaginationProvider(TransactionFilter.all));
    final service = ref.read(transactionServiceProvider);

    // A multisig's past proposals are half of its activity: until they are
    // read, it is not, and when they cannot be, neither can it. A reload
    // keeps the ones read before.
    var past = const <MultisigProposal>[];
    if (account is MultisigAccount) {
      final proposals = ref.watch(multisigPastProposalsProvider(account));
      if (proposals.hasError) return AsyncValue.error(proposals.error!, proposals.stackTrace!);
      if (!proposals.hasValue) return const AsyncValue.loading();
      past = proposals.requireValue;
    }

    return transactions.whenData((data) {
      final parts = partActivityByProgress(activityOf(service, account, data, past));
      return ActivityView(
        inProgress: parts.inProgress,
        settled: parts.settled,
        hasMore: pages?.hasMore ?? false,
        // A page after the first sets the pages loading while they hold some.
        isLoadingMore: pages != null && pages.isLoading && pages.hasLoadedChainData,
      );
    });
  }
}

/// What of [data] an [account]'s panels list, in order: a multisig's [past]
/// proposals and what it received, or any other account's transfers.
List<TransactionEvent> activityOf(
  TransactionService service,
  BaseAccount account,
  CombinedTransactionsList data,
  List<MultisigProposal> past,
) => switch (account) {
  final MultisigAccount msig => multisigActivityOf(service, data, past, msig),
  _ => service.combineAndDeduplicateTransactions(
    pendingCancellationIds: data.pendingCancellationIds,
    pendingTransactions: data.pendingTransactions,
    pendingMultisigCreations: data.pendingMultisigCreations,
    pendingMultisigProposals: data.pendingMultisigProposals,
    pendingMultisigApprovals: data.pendingMultisigApprovals,
    pendingMultisigExecutions: data.pendingMultisigExecutions,
    pendingMultisigCancellations: data.pendingMultisigCancellations,
    scheduledReversibleTransfers: data.scheduledReversibleTransfers,
    otherTransfers: data.otherTransfers,
  ),
};

/// A multisig's open proposals, in order: the ones this device is still
/// proposing, then the open ones, last changed first. Null for any other
/// account.
final openProposalsViewProvider =
    Provider<AsyncValue<({List<PendingMultisigProposalEvent> proposing, List<MultisigProposal> open})>?>((ref) {
      final account = ref.watch(activeAccountProvider).value?.account;
      if (account is! MultisigAccount) return null;
      final proposing = ref.watch(pendingMultisigProposalsProvider);
      return ref
          .watch(multisigOpenProposalsProvider(account))
          .whenData((open) => openProposalsOf(account, proposing: proposing, open: open));
    });

/// The wallet's own accounts and multisigs, by address: a counterparty
/// that is one of them is shown by its badge and name.
final ownAccountsByAddressProvider = Provider<Map<String, BaseAccount>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final multisigs = ref.watch(multisigAccountsProvider).value ?? const <MultisigAccount>[];
  return {
    for (final account in accounts) account.accountId: account,
    for (final multisig in multisigs) multisig.accountId: multisig,
  };
});

/// The swaps listed in In progress of the account [accountId], newest first:
/// those followed from it, one awaiting its deposit among them, and with them
/// any whose account the wallet no longer holds, as after that account was
/// disconnected. Such a swap has no account of its own to be listed under,
/// so it is reached from whichever is open. While the accounts load, no swap
/// is taken for one.
final accountSwapsProvider = Provider.family<List<ActiveSwap>, String>((ref, accountId) {
  final held = ref.watch(accountsProvider).value?.map((account) => account.accountId).toSet();
  return [
    for (final swap in ref.watch(activeSwapsProvider).reversed)
      if (swap.accountId == accountId || (held != null && !held.contains(swap.accountId))) swap,
  ];
});

/// One of the swaps being followed, told apart by its id ([ActiveSwap.id]).
final class OpenedSwap extends OpenedActivity {
  const OpenedSwap(this.swapId);

  final String swapId;

  @override
  String get id => swapId;

  @override
  bool operator ==(Object other) => other is OpenedSwap && other.swapId == swapId;

  @override
  int get hashCode => swapId.hashCode;
}

/// What is open, as the lists hold it now: a transaction by its id, or, once
/// it settled under the indexer's own id, by its hash; a proposal among the
/// past ones or the open ones; a swap while it is followed. A multisig's
/// proposal still being proposed is the pending one, then, once the network
/// has created it, that proposal. Null when it is no longer there. While the
/// lists load, what was opened of them stands.
///
/// A proposal is answered for by its own lists, not the activity, which also
/// waits for the history: what an action did must show once the lists do,
/// or that action is offered again.
final openedActivityViewProvider = Provider<OpenedActivity?>((ref) {
  final opened = ref.watch(openedActivityProvider);
  if (opened == null) return null;
  if (opened is OpenedSwap) return ref.watch(activeSwapProvider(opened.swapId)) == null ? null : opened;
  final account = ref.watch(activeAccountProvider).value?.account;

  // Among the past proposals it is over, whatever the open ones last held.
  OpenedProposal? proposalOf(String entityId) {
    if (account is! MultisigAccount) return null;
    bool same(MultisigProposal other) => other.entityId == entityId;
    final found =
        ref.watch(multisigPastProposalsProvider(account)).value?.where(same).firstOrNull ??
        ref.watch(openProposalsViewProvider)?.value?.open.where(same).firstOrNull;
    return found == null ? null : OpenedProposal(found);
  }

  if (opened case OpenedProposal(:final proposal)) {
    if (account == null) return opened;
    final found = proposalOf(proposal.entityId);
    if (found != null) return found;
    // Until the open proposals first answer, what was opened stands; read
    // without it, or not read, it is no longer open here.
    final open = ref.watch(openProposalsViewProvider);
    return open != null && !open.hasValue && !open.hasError ? opened : null;
  }

  final view = ref.watch(activityViewProvider).value;
  if (view == null) return opened;
  final activity = [...view.inProgress, ...view.settled];

  // A multisig lists what it is proposing among its open proposals, not in
  // its activity.
  if (opened case OpenedTransaction(tx: final PendingMultisigProposalEvent pending)) {
    final proposals = ref.watch(openProposalsViewProvider);
    if (proposals != null) {
      final proposing = proposals.value?.proposing.where((other) => other.id == pending.id).firstOrNull;
      if (proposing != null) return OpenedTransaction(proposing);
      final hash = pending.extrinsicHash;
      final createdId = hash == null ? null : ref.watch(multisigCreatedProposalIdProvider(hash));
      if (createdId == null) return null;
      return proposalOf(createdId) ?? (proposals.isLoading ? opened : null);
    }
  }

  switch (opened) {
    case OpenedTransaction(:final tx):
      final byId = activity.where((other) => other.id == tx.id).firstOrNull;
      if (byId != null) return OpenedTransaction(byId);
      final hash = tx.extrinsicHash;
      if (hash == null) return null;
      final byHash = activity.where((other) => other.extrinsicHash == hash).firstOrNull;
      return byHash == null ? null : OpenedTransaction(byHash);
    case OpenedSwap():
      throw StateError('A swap is answered for before the lists are read.');
    case OpenedProposal():
      throw StateError('A proposal is answered for by its lists, before the activity is read.');
  }
});
