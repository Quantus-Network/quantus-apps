import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

/// Where a notification's metadata holds the hash of its transaction.
const notificationHashKey = 'extrinsicHash';

/// Where a notification's metadata holds the id the lists know its proposal
/// by. The transaction that created a proposal does not name it: one
/// transaction can create several.
const notificationProposalKey = 'proposalId';

/// Where a notification's metadata holds the id of the followed swap it is
/// about ([ActiveSwap.id]).
const notificationSwapKey = 'swapId';

/// What a click on [notification] needs to find what it was about.
String notificationClickPayload(NotificationData notification) => jsonEncode({
  'accountId': notification.accountId,
  if (notification.metadata?[notificationHashKey] case final String hash) notificationHashKey: hash,
  if (notification.metadata?[notificationProposalKey] case final String proposalId) notificationProposalKey: proposalId,
  if (notification.metadata?[notificationSwapKey] case final String swapId) notificationSwapKey: swapId,
});

/// Opens what a clicked notification was about: the window comes to the
/// front, on the account it named, with its transaction or proposal open
/// when the loaded activity holds it, or its swap while it is followed.
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
    final String? proposalId;
    final String? swapId;
    try {
      final clicked = jsonDecode(payload!) as Map<String, dynamic>;
      accountId = clicked['accountId'] as String;
      hash = clicked[notificationHashKey] as String?;
      proposalId = clicked[notificationProposalKey] as String?;
      swapId = clicked[notificationSwapKey] as String?;
    } catch (e) {
      quantusPrint('A clicked notification could not be read: $e');
      _ref.read(telemetryProvider).sendError('desktop_notification_click_unreadable', error: e);
      return;
    }
    _start(accountId, hash: hash, proposalId: proposalId, swapId: swapId);
  }

  /// Opens the followed swap [swapId], from [accountId], as a click on its
  /// notification does: it was picked from the menu bar icon's menu.
  void openSwap({required String swapId, required String accountId}) {
    unawaited(const WindowChrome().bringToFront());
    _start(accountId, hash: null, proposalId: null, swapId: swapId);
  }

  /// Follows a click on what is about [accountId], in place of any before it.
  void _start(String accountId, {required String? hash, required String? proposalId, required String? swapId}) {
    _cancelWait?.call();
    final click = Object();
    _current = click;
    unawaited(_follow(click, accountId, hash: hash, proposalId: proposalId, swapId: swapId));
  }

  /// Drops the click being followed: its wallet was wiped.
  void drop() {
    _current = null;
    _cancelWait?.call();
  }

  Future<void> _follow(
    Object click,
    String accountId, {
    required String? hash,
    required String? proposalId,
    required String? swapId,
  }) async {
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
    if (swapId != null) return _openSwap(click, account, swapId);
    if (account == null) return;

    await _ref.read(sidebarNavigatorProvider).showAccount(account);
    if ((hash == null && proposalId == null) || !_isShowing(click, accountId)) return;

    final leaving = _dropWhenLeft(click, accountId);
    try {
      await _openListed(
        click,
        accountId,
        hash: hash,
        proposalId: proposalId,
        isMultisig: account.account is MultisigAccount,
      );
    } finally {
      for (final subscription in leaving) {
        subscription.close();
      }
    }
  }

  /// Opens the followed swap [swapId] on [account], the one it is from. A
  /// swap whose account the wallet no longer holds is listed under whichever
  /// account is in front, so it opens there; one no longer followed leaves
  /// only its account showing.
  Future<void> _openSwap(Object click, DisplayAccount? account, String swapId) async {
    final showing = account ?? _ref.read(activeAccountProvider).value;
    if (showing == null) return;
    await _ref.read(sidebarNavigatorProvider).showAccount(showing);
    if (!_isShowing(click, showing.account.accountId)) return;
    if (_ref.read(activeSwapProvider(swapId)) == null) return;
    _ref.read(openedActivityProvider.notifier).open(OpenedSwap(swapId));
  }

  /// Drops [click] for good once its account is no longer in front: coming
  /// back before a slow answer arrives does not bring the click back.
  List<ProviderSubscription<Object?>> _dropWhenLeft(Object click, String accountId) {
    void check() {
      if (!identical(_current, click) || _isShowing(click, accountId)) return;
      _current = null;
      _cancelWait?.call();
    }

    return [
      for (final provider in <ProviderListenable<Object?>>[activeAccountProvider, shellSheetProvider])
        _ref.listen(provider, (_, _) => check()),
    ];
  }

  /// Opens what the transaction [hash] was, once the lists hold it: as they
  /// are, or else read once more.
  ///
  /// A notification that names its proposal is taken at its word. One that
  /// names only a transaction in a multisig is asked of the indexer, which
  /// answers with the proposal that transaction created, if it created one.
  Future<void> _openListed(
    Object click,
    String accountId, {
    required String? hash,
    required String? proposalId,
    required bool isMultisig,
  }) async {
    var listedAs = proposalId;
    if (listedAs == null && isMultisig) {
      // A click that names no proposal names a transaction.
      final created = await _proposalCreatedIn(hash!);
      if (created == null || !_isShowing(click, accountId)) return;
      listedAs = created.proposalId;
    }

    if (!await _untilListsLoaded(click, accountId)) return;
    if (listedAs != null) {
      // What happened to the proposal is newer than the lists read before
      // it, and showing the multisig already in front reads nothing: without
      // this it would open as it was, or not at all.
      if (!await _readProposalsAgain() || !await _untilListsLoaded(click, accountId)) return;
    }
    var activity = _listedActivity(hash: hash, proposalId: listedAs);
    if (activity == null) {
      // What the notification is about can be newer than the rows last
      // read, and showing the account already in front reads nothing.
      await silentRefreshActiveAccount(_ref);
      if (!await _untilListsLoaded(click, accountId)) return;
      activity = _listedActivity(hash: hash, proposalId: listedAs);
    }
    if (activity != null) _ref.read(openedActivityProvider.notifier).open(activity);
  }

  /// Reads the proposals of the multisig in front again. False when they
  /// cannot be read: the proposal is then not opened as it was before.
  Future<bool> _readProposalsAgain() async {
    try {
      await refreshActiveMultisigProposals(_ref);
      return true;
    } catch (e) {
      quantusPrint('The proposals of a clicked notification could not be read again: $e');
      if (_ref.mounted) _ref.read(telemetryProvider).sendError('desktop_notification_proposals_unread', error: e);
      return false;
    }
  }

  /// Waits for the lists of the account in front. False when they cannot be
  /// read, or the click is no longer followed there.
  Future<bool> _untilListsLoaded(Object click, String accountId) => _until(click, [
    activityViewProvider,
    openProposalsViewProvider,
  ], () => _isShowing(click, accountId) ? _listsLoaded() : false);

  /// Whether the click is still the latest and its account still in front.
  bool _isShowing(Object click, String accountId) =>
      _ref.mounted &&
      identical(_current, click) &&
      _ref.read(shellSheetProvider) == null &&
      _ref.read(activeAccountProvider).value?.account.accountId == accountId;

  /// The id of the proposal created in the transaction [hash], which is what
  /// the lists know it by; no id when the transaction created none, as a
  /// transfer the multisig received did not. Null when it cannot be told.
  Future<({String? proposalId})?> _proposalCreatedIn(String hash) async {
    try {
      final created = await _ref
          .read(chainHistoryServiceProvider)
          .searchProposalCreatedByExtrinsicHash(extrinsicHash: hash);
      if (created == null) return (proposalId: null);
      final proposalId = created.proposal?.entityId;
      return proposalId == null ? null : (proposalId: proposalId);
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
  OpenedActivity? _listedActivity({required String? hash, required String? proposalId}) {
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
