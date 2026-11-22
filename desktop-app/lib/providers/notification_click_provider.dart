import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Where a notification's metadata holds the hash of its transaction.
const notificationHashKey = 'extrinsicHash';

/// What a click on [notification] needs to find what it was about.
String notificationClickPayload(NotificationData notification) => jsonEncode({
  'accountId': notification.accountId,
  if (notification.metadata?[notificationHashKey] case final String hash) notificationHashKey: hash,
});

/// Opens what a clicked notification was about: the window comes to the
/// front, on the account it named, with its transaction or proposal open
/// when the loaded activity holds it.
///
/// A click never gets in the way: nothing moves behind an open sheet, and it
/// is dropped once the person goes elsewhere or clicks another notification.
class NotificationClick {
  NotificationClick(this._ref) {
    _ref.onDispose(() => _cancelWait?.call());
  }

  final Ref _ref;

  /// The click being followed.
  Object? _current;

  /// Ends the wait of the click being followed.
  void Function()? _cancelWait;

  void open(String? payload) {
    unawaited(const WindowChrome().bringToFront());
    final String accountId;
    final String? hash;
    try {
      final clicked = jsonDecode(payload!) as Map<String, dynamic>;
      accountId = clicked['accountId'] as String;
      hash = clicked[notificationHashKey] as String?;
    } catch (e) {
      quantusPrint('A clicked notification could not be read: $e');
      _ref.read(telemetryProvider).sendError('desktop_notification_click_unreadable', error: e);
      return;
    }
    _cancelWait?.call();
    final click = Object();
    _current = click;
    unawaited(_follow(click, accountId, hash));
  }

  Future<void> _follow(Object click, String accountId, String? hash) async {
    // Before they have loaded, restoring the saved active account would undo
    // the switch.
    final loaded = await _until(click, [sidebarAccountsProvider, activeAccountProvider], () {
      final accountsLoaded = _ref.read(sidebarAccountsProvider).isNotEmpty;
      return accountsLoaded && _ref.read(activeAccountProvider).hasValue ? true : null;
    });
    if (!loaded || !_ref.mounted || !identical(_current, click) || _ref.read(shellSheetProvider) != null) return;
    final account = _ref
        .read(sidebarAccountsProvider)
        .where((display) => display.account.accountId == accountId)
        .firstOrNull;
    if (account == null) return;

    await _ref.read(sidebarSelectionProvider.notifier).showAccount(account);
    if (hash == null || !_isShowing(click, accountId)) return;

    final String? proposalId;
    if (account.account is MultisigAccount) {
      proposalId = await _proposalCreatedIn(hash);
      if (proposalId == null || !_isShowing(click, accountId)) return;
    } else {
      proposalId = null;
    }

    final listsLoaded = await _until(click, [
      activityViewProvider,
      openProposalsViewProvider,
      activeAccountProvider,
      sidebarSelectionProvider,
      shellSheetProvider,
    ], () => _isShowing(click, accountId) ? _listsLoaded() : false);
    if (!listsLoaded) return;

    final activity = _listedActivity(hash: hash, proposalId: proposalId);
    if (activity != null) _ref.read(openedActivityProvider.notifier).open(activity);
  }

  /// Whether the click is still the latest and its account still in front.
  bool _isShowing(Object click, String accountId) =>
      _ref.mounted &&
      identical(_current, click) &&
      _ref.read(shellSheetProvider) == null &&
      _ref.read(sidebarSelectionProvider) == SidebarSelection.account &&
      _ref.read(activeAccountProvider).value?.account.accountId == accountId;

  /// The id of the proposal created in the transaction [hash], which is what
  /// the lists know it by. Null when it cannot be told.
  Future<String?> _proposalCreatedIn(String hash) async {
    try {
      final created = await _ref
          .read(chainHistoryServiceProvider)
          .searchProposalCreatedByExtrinsicHash(extrinsicHash: hash);
      return created?.proposal?.entityId;
    } catch (e) {
      quantusPrint('The proposal of a clicked notification could not be read: $e');
      if (_ref.mounted) _ref.read(telemetryProvider).sendError('desktop_notification_proposal_unread', error: e);
      return null;
    }
  }

  /// True once the lists have loaded, false if they cannot, null until then.
  bool? _listsLoaded() {
    final activity = _ref.read(activityViewProvider);
    final open = _ref.read(openProposalsViewProvider);
    if (!activity.hasValue && activity.hasError) return false;
    if (open != null && !open.hasValue && open.hasError) return false;
    if (!activity.hasValue || activity.requireValue.isReloading) return null;
    if (open != null && !open.hasValue) return null;
    return true;
  }

  /// What the loaded lists hold of the transaction [hash], or of the proposal
  /// [proposalId] when there is one.
  OpenedActivity? _listedActivity({required String hash, required String? proposalId}) {
    final view = _ref.read(activityViewProvider).requireValue;
    final rows = [...view.inProgress, ...view.settled];
    if (proposalId == null) {
      final row = rows.where((tx) => tx.extrinsicHash == hash).firstOrNull;
      return row == null ? null : OpenedTransaction(row);
    }
    final proposals = [
      ...?_ref.read(openProposalsViewProvider)?.value?.open,
      for (final tx in rows)
        if (tx is MultisigProposalEvent) tx.proposal,
    ];
    final proposal = proposals.where((other) => other.entityId == proposalId).firstOrNull;
    return proposal == null ? null : OpenedProposal(proposal);
  }

  /// Waits for [answer], asked now and whenever one of [watched] changes, to
  /// say true or false. False too when a newer click replaces this one.
  Future<bool> _until(Object click, List<ProviderListenable<Object?>> watched, bool? Function() answer) {
    if (!_ref.mounted || !identical(_current, click)) return Future.value(false);
    final now = answer();
    if (now != null) return Future.value(now);

    final done = Completer<bool>();
    final subscriptions = <ProviderSubscription<Object?>>[];
    void finish(bool result) {
      if (done.isCompleted) return;
      for (final subscription in subscriptions) {
        subscription.close();
      }
      _cancelWait = null;
      done.complete(result);
    }

    _cancelWait = () => finish(false);
    for (final provider in watched) {
      subscriptions.add(
        _ref.listen(provider, (_, _) {
          if (done.isCompleted) return;
          final next = answer();
          if (next != null) finish(next);
        }),
      );
    }
    return done.future;
  }
}

final notificationClickProvider = Provider<NotificationClick>(NotificationClick.new);
