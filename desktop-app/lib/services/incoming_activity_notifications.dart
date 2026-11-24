import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/notification_delivery.dart';
import 'package:quantus_desktop_wallet/services/own_activity_notifications.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/wallet_session.dart';

/// Notifies what reaches the wallet from outside it while the app runs: a
/// transfer that arrived, a reversible transfer scheduled to arrive, and what
/// a multisig's other signers do to its proposals.
///
/// It reads the indexer for every Transparent account and multisig, not only
/// the one in front. An Encrypted account is left out: finding what it
/// received takes its recovery phrase. What happened while the app was not
/// running is not notified: each account is read on from where its history
/// ended when the app first read it.
///
/// What the person does themselves is not notified here: what this computer
/// sends and proposes is for [OwnActivityNotifications], and what one of the
/// wallet's own accounts did elsewhere they already know.
class IncomingActivityNotifications {
  /// How often the indexer is read.
  static const pollInterval = Duration(minutes: 1);

  IncomingActivityNotifications(this._ref) {
    _ref.onDispose(_stop);
    _ref.listen(walletPresenceProvider, (_, _) => _update());
    _ref.listen(isOnlineProvider, (_, _) => _update());
    _ref.listen(windowClosedProvider, (_, _) => _update());
    _update();
  }

  final Ref _ref;

  /// Where each account is read on from. An account not in it has not been
  /// read yet.
  final _cursors = <String, AccountEventCursor>{};

  /// Where each multisig's proposals are read on from.
  final _proposalCursors = <String, MultisigProposalActivityCursor>{};

  /// Runs while the indexer is being read every [pollInterval].
  Timer? _timer;

  /// Open while the indexer is being read: an account just added is given its
  /// starting point at once, so that what it receives from then on is
  /// notified. Not before there is a wallet: listening loads its accounts,
  /// and there are none to load yet.
  List<ProviderSubscription<Object?>> _accountChanges = const [];

  bool _isReading = false;

  /// Whether a read was asked for while one was under way.
  bool _readAgain = false;

  /// The reads failing now, by the name each was reported under: once, while
  /// it lasts.
  final _failuresReported = <String>{};

  /// Whether there is a wallet to read for and a way to read: with no
  /// network there is nothing to ask, and with the window closed the app
  /// stays only for the work it is finishing.
  bool get _shouldWatch =>
      _ref.read(walletPresenceProvider).value == WalletPresence.present &&
      _ref.read(isOnlineProvider) &&
      !_ref.read(windowClosedProvider);

  /// Starts or stops the reading as [_shouldWatch] says. Starting reads at
  /// once, which catches up on what arrived while it was stopped.
  void _update() {
    if (_ref.read(walletPresenceProvider).value == WalletPresence.none) {
      _cursors.clear();
      _proposalCursors.clear();
    }
    if (!_shouldWatch) return _stop();
    if (_timer != null) return;
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_read()));
    _accountChanges = [
      _ref.listen(accountsProvider, (_, _) => unawaited(_read())),
      _ref.listen(multisigAccountsProvider, (_, _) => unawaited(_read())),
    ];
    unawaited(_read());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    for (final subscription in _accountChanges) {
      subscription.close();
    }
    _accountChanges = const [];
  }

  /// Reads the indexer, and once more when asked again meanwhile: the
  /// accounts may have changed since the read under way began.
  Future<void> _read() async {
    if (_isReading) {
      _readAgain = true;
      return;
    }
    _isReading = true;
    try {
      do {
        _readAgain = false;
        await _readOnce();
      } while (_readAgain && _ref.mounted && _shouldWatch);
    } finally {
      _isReading = false;
    }
  }

  Future<void> _readOnce() async {
    final accounts = _ref.read(accountsProvider).value;
    final multisigs = _ref.read(multisigAccountsProvider).value;
    // Still loading: read once they are known.
    if (accounts == null || multisigs == null) return;
    final session = _ref.read(walletSessionProvider);
    final ticket = session.ticket;
    // Each reports its own failure: one that fails does not stop the other.
    await Future.wait([
      _readReceived(accounts, multisigs, session, ticket),
      _readProposals(multisigs, session, ticket),
    ]);
  }

  Future<void> _readReceived(
    List<Account> accounts,
    List<MultisigAccount> multisigs,
    WalletSession session,
    int ticket,
  ) async {
    final watched = <String>{
      for (final account in accounts)
        if (account.accountType != AccountType.encrypted) account.accountId,
      for (final multisig in multisigs) multisig.accountId,
    };
    _cursors.removeWhere((accountId, _) => !watched.contains(accountId));
    if (watched.isEmpty) return;

    final read = await _reported(
      'desktop_notification_incoming_unread',
      () => _ref.read(chainHistoryServiceProvider).fetchIncomingSince({
        for (final accountId in watched) accountId: _cursors[accountId],
      }),
    );
    if (read == null) return;
    if (!_ref.mounted || !session.stillCurrent(ticket, dropping: 'what the accounts received')) return;

    for (final MapEntry(key: accountId, value: since) in read.entries) {
      _cursors[accountId] = since.cursor;
      for (final event in since.received) {
        _notify(accountId, event);
      }
    }
  }

  Future<void> _readProposals(List<MultisigAccount> multisigs, WalletSession session, int ticket) async {
    _proposalCursors.removeWhere((multisigId, _) => !multisigs.any((multisig) => multisig.accountId == multisigId));
    if (multisigs.isEmpty) return;

    final read = await _reported(
      'desktop_notification_proposals_unread',
      () => _ref.read(multisigServiceProvider).fetchProposalActivitySince(multisigs, {..._proposalCursors}),
    );
    if (read == null) return;
    if (!_ref.mounted || !session.stillCurrent(ticket, dropping: 'what happened to the proposals')) return;

    for (final MapEntry(key: multisigId, value: since) in read.entries) {
      _proposalCursors[multisigId] = since.cursor;
      for (final happened in since.activity) {
        _notifyProposal(multisigId, happened);
      }
    }
  }

  /// What [read] answers, or null when it fails: the failure is reported as
  /// [name], once while it lasts. The cursors stay where they are, so the
  /// next read asks for the same.
  Future<T?> _reported<T extends Object>(String name, Future<T> Function() read) async {
    final T answer;
    try {
      answer = await read();
    } catch (e) {
      quantusPrint('Reading the indexer failed ($name): $e');
      if (_ref.mounted && _failuresReported.add(name)) _ref.read(telemetryProvider).sendError(name, error: e);
      return null;
    }
    _failuresReported.remove(name);
    return answer;
  }

  /// Notifies that the account [accountId] received [event], unless it is the
  /// person's own send: one from another of the wallet's own accounts, on
  /// this computer or another, or what an Encrypted send from this computer
  /// paid. A multisig is not the person's alone, so what it pays is notified.
  void _notify(String accountId, TransactionEvent event) {
    final accounts = _ref.read(accountsProvider).value ?? const <Account>[];
    final multisigs = _ref.read(multisigAccountsProvider).value ?? const <MultisigAccount>[];
    final BaseAccount? account =
        accounts.where((a) => a.accountId == accountId).firstOrNull ??
        multisigs.where((m) => m.accountId == accountId).firstOrNull;
    if (account == null) {
      quantusPrint('Not notifying what an account no longer in the wallet received: ${event.id}');
      return;
    }
    if (accounts.any((own) => own.accountId == event.from)) return;
    final hash = event.extrinsicHash;
    if (hash != null && _ref.read(ownActivityNotificationsProvider).isEncryptedSendFromHere(hash)) return;

    final delivery = _ref.read(notificationDeliveryProvider);
    final l10n = _ref.read(l10nProvider);
    final amount = delivery.amountText(event.amount);
    switch (event) {
      case ReversibleTransferEvent():
        delivery.show(
          id: 'incoming_${event.id}',
          accountId: account.accountId,
          accountName: account.name,
          extrinsicHash: hash,
          intent: NotificationIntent.reversibleTransactions,
          title: l10n.desktopNotificationIncomingTitle(amount),
          body: l10n.desktopNotificationIncomingBody(account.name),
        );
      case TransferEvent():
        delivery.show(
          id: 'received_${event.id}',
          accountId: account.accountId,
          accountName: account.name,
          extrinsicHash: hash,
          intent: NotificationIntent.receivedTokens,
          title: l10n.desktopNotificationReceivedTitle(amount),
          body: l10n.desktopNotificationReceivedBody(account.name),
        );
      default:
        throw StateError('Neither a transfer nor a scheduled transfer was read as received: $event');
    }
  }

  /// Notifies what [happened] to a proposal of the multisig [multisigId],
  /// unless one of the wallet's own accounts did it.
  ///
  /// The approval that makes a proposal ready is recorded twice, as that
  /// approval and as the proposal being ready; and so is a proposal made
  /// where one approval is enough. Each is notified once, as ready.
  void _notifyProposal(String multisigId, MultisigProposalActivity happened) {
    final multisigs = _ref.read(multisigAccountsProvider).value ?? const <MultisigAccount>[];
    final multisig = multisigs.where((m) => m.accountId == multisigId).firstOrNull;
    if (multisig == null) {
      quantusPrint('Not notifying what happened in a multisig no longer in the wallet: ${happened.id}');
      return;
    }
    final accounts = _ref.read(accountsProvider).value ?? const <Account>[];
    if (accounts.any((own) => own.accountId == happened.actor)) return;

    final l10n = _ref.read(l10nProvider);
    final proposal = happened.proposal;
    final String title;
    switch (happened.kind) {
      case MultisigProposalActivityKind.created:
        if (proposal.threshold <= 1) return;
        title = l10n.desktopNotificationProposalNewTitle;
      case MultisigProposalActivityKind.signed:
        final approvals = happened.approvalsCount!;
        if (approvals >= proposal.threshold) return;
        title = l10n.desktopNotificationProposalSignedTitle(approvals, proposal.threshold);
      case MultisigProposalActivityKind.ready:
        title = l10n.desktopNotificationProposalReadyTitle;
      case MultisigProposalActivityKind.executed:
        title = happened.succeeded!
            ? l10n.desktopNotificationProposalExecutedTitle
            : l10n.desktopNotificationProposalFailedTitle;
      case MultisigProposalActivityKind.cancelled:
        title = l10n.desktopNotificationProposalCancelledTitle;
      case MultisigProposalActivityKind.removed:
        title = l10n.desktopNotificationProposalRemovedTitle;
    }
    final delivery = _ref.read(notificationDeliveryProvider);
    delivery.show(
      id: 'proposal_${happened.kind.name}_${happened.id}',
      accountId: multisig.accountId,
      accountName: multisig.name,
      extrinsicHash: happened.creationHash,
      // What the lists know the proposal by: a click opens it. The
      // transaction that created it may have created others too.
      proposalId: proposal.entityId,
      intent: NotificationIntent.others,
      title: title,
      // A proposal that is not a transfer has no recipient and no amount.
      body: proposal.recipient.isEmpty
          ? l10n.desktopNotificationProposalOtherBody(multisig.name)
          : l10n.desktopNotificationProposalCreatedBody(delivery.amountText(proposal.amount), multisig.name),
    );
  }
}

final incomingActivityNotificationsProvider = Provider<IncomingActivityNotifications>(
  IncomingActivityNotifications.new,
);
