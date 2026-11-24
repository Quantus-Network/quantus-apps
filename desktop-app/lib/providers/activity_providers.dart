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

/// The swap this app follows. It follows one at a time: while there is one,
/// Swap opens it instead of the form for another. Should a second have started
/// all the same, as when a deposit lands after its sheet was left, it is the
/// newest, and the one before it shows once that is put away.
final followedSwapProvider = Provider<ActiveSwap?>((ref) => ref.watch(activeSwapsProvider).lastOrNull);

/// The swaps followed from the account [accountId], newest first: its rows
/// in In progress, one awaiting its deposit among them.
final accountSwapsProvider = Provider.family<List<ActiveSwap>, String>(
  (ref, accountId) => [
    for (final swap in ref.watch(activeSwapsProvider).reversed)
      if (swap.accountId == accountId) swap,
  ],
);

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
/// open ones or the past ones; a swap while it is followed. Null when it is
/// no longer there. While the lists load, what was opened of them stands.
final openedActivityViewProvider = Provider<OpenedActivity?>((ref) {
  final opened = ref.watch(openedActivityProvider);
  if (opened == null) return null;
  if (opened is OpenedSwap) return ref.watch(activeSwapProvider(opened.swapId)) == null ? null : opened;
  final view = ref.watch(activityViewProvider).value;
  if (view == null) return opened;
  final activity = [...view.inProgress, ...view.settled];

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
    case OpenedProposal(:final proposal):
      final open = ref.watch(openProposalsViewProvider)?.value?.open ?? const <MultisigProposal>[];
      final past = [
        for (final tx in activity)
          if (tx is MultisigProposalEvent) tx.proposal,
      ];
      final found = [...open, ...past].where((other) => other.entityId == proposal.entityId).firstOrNull;
      return found == null ? null : OpenedProposal(found);
  }
});
