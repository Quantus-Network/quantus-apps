import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/notification_click_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/extrinsic_indexer_polling_service.dart';
import 'package:wallet_core/services/pending_transaction_polling_service.dart';
import 'package:wallet_core/services/telemetry.dart';

/// An Encrypted send handed to the node: one transaction for each batch of
/// its inputs.
class _EncryptedSend {
  _EncryptedSend({required this.account, required this.amount, required List<String> hashes})
    : lastHash = hashes.last,
      unseen = {...hashes};

  final Account account;
  final BigInt amount;

  /// What the account's history knows the send by.
  final String lastHash;

  /// The transactions the chain has not shown yet.
  final Set<String> unseen;

  bool readFailureReported = false;
}

/// Notifies what this computer itself did, once the chain has had its say: a
/// Transparent or Encrypted send confirmed, failed or not seen in time, and a
/// proposal made here created or not seen in time.
///
/// What happens elsewhere (funds received, what other signers do) is for
/// remote notifications.
class OwnActivityNotifications {
  /// How long a notification handed over still needs the app: macOS's
  /// notification plugin answers before macOS has taken it.
  static const settleDelay = Duration(seconds: 2);

  OwnActivityNotifications(this._ref) {
    _ref.onDispose(() {
      for (final timer in _settling) {
        timer.cancel();
      }
    });
    _ref.listen(pendingTransactionsProvider, (_, sends) => _onSends(sends));
    _ref.listen(pendingMultisigProposalsProvider, (_, proposals) => _onProposals(proposals));
    _ref.listen(
      multisigProposalConfirmationsProvider,
      (previous, settled) => _onSettled(previous ?? const {}, settled),
    );
    _ref.listen(walletPresenceProvider, (_, presence) {
      if (presence.value == WalletPresence.none) _stopWatchingEncryptedSends();
    });
    _ref.onDispose(() => _encryptedSendWatch.dispose());
  }

  final Ref _ref;

  /// The Encrypted sends handed to the node and not yet seen on the chain, by
  /// the hash of the last transaction of each.
  final _encryptedSends = <String, _EncryptedSend>{};

  late final _encryptedSendWatch = ExtrinsicIndexerPollingService<_EncryptedSend, void>(
    _ref,
    ExtrinsicIndexerPollingConfig(
      logPrefix: '[EncryptedSendNotification]',
      getId: (send) => send.lastHash,
      getExtrinsicHash: (send) => send.lastHash,
      isStillPending: (_, id) => _encryptedSends.containsKey(id),
      removePending: (_, id) => _giveUpOnEncryptedSend(id),
      // The notification says so.
      showTimeoutToast: (_) {},
      confirmIfIndexed: (_, _, send) => _confirmEncryptedSend(send),
    ),
  );

  /// The broadcast sends being watched, by id, with when each was broadcast.
  final _sends = <String, ({PendingTransactionEvent send, DateTime broadcastAt})>{};

  /// The proposals broadcast from here, by the hash of the transaction each
  /// was sent in. Kept until their outcome is known: a created proposal
  /// leaves the pending proposals before that.
  final _proposals = <String, PendingMultisigProposalEvent>{};

  /// One for each notification handed over less than [settleDelay] ago.
  final _settling = <Timer>{};

  /// Whether a notification was handed over so recently that quitting now
  /// could still lose it.
  bool get isSettling => _settling.isNotEmpty;

  /// Counts [delivering], which reports its own failures, as work under way
  /// until it is done.
  void _holdWhile(Future<void> delivering) {
    final holds = _ref.read(workHoldsProvider.notifier);
    holds.hold(delivering);
    unawaited(delivering.whenComplete(() => holds.release(delivering)));
  }

  void _onSends(List<PendingTransactionEvent> sends) {
    final now = clock.now();
    for (final send in sends) {
      final watched = _sends[send.id];
      switch (send.transactionState) {
        case TransactionState.pending when watched == null:
          _sends[send.id] = (send: send, broadcastAt: now);
        case TransactionState.inHistory when watched != null:
          _sends.remove(send.id);
          _holdWhile(_notifySent(send));
        case TransactionState.failed when watched != null:
          _sends.remove(send.id);
          // The amount it was recorded with: what it set out to send.
          _notifySend(
            send,
            amount: send.amount,
            title: (l10n, _) => l10n.desktopNotificationSendFailedTitle,
            body: (l10n, amount, account) => l10n.desktopNotificationSendFailedBody(amount, account),
          );
        default:
          break;
      }
    }
    final present = {for (final send in sends) send.id};
    for (final id in _sends.keys.where((id) => !present.contains(id)).toList()) {
      final (:send, :broadcastAt) = _sends.remove(id)!;
      // Gone unfound: the wallet gave up on it, which it does only once it
      // has watched for the whole time. A wipe empties the list at any time.
      if (now.difference(broadcastAt) < PendingTransactionPollingService.timeout) continue;
      _notifySend(
        send,
        amount: send.amount,
        title: (l10n, _) => l10n.desktopNotificationSendNotConfirmedTitle,
        body: (l10n, amount, account) => l10n.desktopNotificationSendNotConfirmedBody(amount, account),
      );
    }
  }

  /// Notifies [send] as sent, with the amount the chain moved: a Max send
  /// is recorded with an estimate, as the chain sizes it at inclusion, and
  /// its record is not corrected when it is found.
  Future<void> _notifySent(PendingTransactionEvent send) async {
    final TransactionEvent? indexed;
    try {
      final hash = send.extrinsicHash;
      if (hash == null) throw StateError('A broadcast send has no transaction hash: ${send.id}');
      indexed = await _ref
          .read(chainHistoryServiceProvider)
          .searchByExtrinsicHash(extrinsicHash: hash, isReversible: send.isReversible);
      if (indexed == null) throw StateError('The indexer does not hold the send it was found in: ${send.id}');
    } catch (e) {
      // Without the amount the chain moved there is nothing true to say.
      quantusPrint('Not notifying a confirmed send whose amount could not be read: $e');
      _ref.read(telemetryProvider).sendError('desktop_notification_sent_amount_unread', error: e);
      return;
    }
    _notifySend(
      send,
      amount: indexed.amount,
      title: (l10n, amount) => l10n.desktopNotificationSentTitle(amount),
      body: (l10n, _, account) => l10n.desktopNotificationSentBody(account),
    );
  }

  /// Takes in how an Encrypted send's proving ended, from the sheet that runs
  /// it: listening to the proving from here would keep it alive after the
  /// sheet has gone.
  ///
  /// A send handed over is only in the node's pool, so it is notified once
  /// the chain holds every one of its transactions. One the person cancelled
  /// is not notified: the sheet in front of them says what became of it.
  void onEncryptedSendEnded({required Account account, required BigInt amount, required EncryptedSendState send}) {
    switch (send.phase) {
      case EncryptedSendPhase.succeeded:
        if (send.txHashes.isEmpty) {
          final error = StateError('An Encrypted send was handed over with no transaction');
          quantusPrint('Not notifying: $error');
          _ref.read(telemetryProvider).sendError('desktop_notification_encrypted_send_no_hash', error: error);
          return;
        }
        final watched = _EncryptedSend(account: account, amount: amount, hashes: send.txHashes);
        _encryptedSends[watched.lastHash] = watched;
        // Work under way until its notification is on its way.
        _ref.read(workHoldsProvider.notifier).hold(watched);
        _encryptedSendWatch.startPolling(null, watched);
      case EncryptedSendPhase.failed:
        // Some of its batches may have paid before it failed; only the
        // error's text says.
        _notifyFrom(
          account.accountId,
          id: 'encrypted_${clock.now().microsecondsSinceEpoch}',
          extrinsicHash: null,
          amount: amount,
          title: (l10n, _) => l10n.desktopNotificationSendFailedTitle,
          body: (l10n, amount, account) => l10n.desktopNotificationEncryptedSendFailedBody(amount, account),
        );
      case EncryptedSendPhase.planStale:
        _notifyFrom(
          account.accountId,
          id: 'encrypted_${clock.now().microsecondsSinceEpoch}',
          extrinsicHash: null,
          amount: amount,
          title: (l10n, _) => l10n.desktopNotificationSendFailedTitle,
          body: (l10n, amount, account) => l10n.desktopNotificationSendFailedBody(amount, account),
        );
      case EncryptedSendPhase.idle ||
          EncryptedSendPhase.running ||
          EncryptedSendPhase.canceling ||
          EncryptedSendPhase.cancelled:
        break;
    }
  }

  /// Whether the chain holds all of [send] by now, in which case it is
  /// notified. Answers true too for a send no longer watched.
  Future<bool> _confirmEncryptedSend(_EncryptedSend send) async {
    final history = _ref.read(chainHistoryServiceProvider);
    try {
      for (final hash in send.unseen.toList()) {
        if (!_encryptedSends.containsKey(send.lastHash)) return true;
        if (await history.searchByExtrinsicHash(extrinsicHash: hash, isReversible: false) == null) return false;
        send.unseen.remove(hash);
      }
    } catch (e) {
      quantusPrint('Reading an Encrypted send from the indexer failed: $e');
      if (!send.readFailureReported && _ref.mounted) {
        send.readFailureReported = true;
        _ref.read(telemetryProvider).sendError('desktop_notification_encrypted_send_unread', error: e);
      }
      return false;
    }
    if (_encryptedSends.remove(send.lastHash) == null || !_ref.mounted) return true;
    try {
      await _reloadEncryptedState(send.account.walletIndex);
      if (!_ref.mounted) return true;
      _notifyFrom(
        send.account.accountId,
        id: send.lastHash,
        extrinsicHash: send.lastHash,
        amount: send.amount,
        title: (l10n, amount) => l10n.desktopNotificationSentTitle(amount),
        body: (l10n, _, account) => l10n.desktopNotificationSentBody(account),
      );
    } finally {
      _releaseEncryptedSend(send);
    }
    return true;
  }

  void _releaseEncryptedSend(_EncryptedSend send) {
    if (_ref.mounted) _ref.read(workHoldsProvider.notifier).release(send);
  }

  /// Reads the account's state again, for a click on the notification to find
  /// the send in its history. A read that fails does not undo the send.
  Future<void> _reloadEncryptedState(int walletIndex) async {
    final state = encryptedStateProvider(walletIndex);
    _ref.invalidate(state);
    try {
      await _ref.read(state.future);
    } catch (e) {
      quantusPrint('Reading the Encrypted account after its send failed: $e');
      if (_ref.mounted) {
        _ref.read(telemetryProvider).sendError('desktop_notification_encrypted_reload_failed', error: e);
      }
    }
  }

  void _giveUpOnEncryptedSend(String id) {
    final send = _encryptedSends.remove(id);
    if (send == null) return;
    try {
      _notifyFrom(
        send.account.accountId,
        id: send.lastHash,
        extrinsicHash: send.lastHash,
        amount: send.amount,
        title: (l10n, _) => l10n.desktopNotificationSendNotConfirmedTitle,
        body: (l10n, amount, account) => l10n.desktopNotificationSendNotConfirmedBody(amount, account),
      );
    } finally {
      _releaseEncryptedSend(send);
    }
  }

  void _stopWatchingEncryptedSends() {
    _encryptedSendWatch.stopAll();
    _encryptedSends.values.forEach(_releaseEncryptedSend);
    _encryptedSends.clear();
  }

  void _onProposals(List<PendingMultisigProposalEvent> proposals) {
    for (final proposal in proposals) {
      final hash = proposal.extrinsicHash;
      if (hash != null) _proposals[hash] = proposal;
    }
  }

  void _onSettled(Map<String, SendConfirmation> previous, Map<String, SendConfirmation> settled) {
    for (final MapEntry(key: hash, value: outcome) in settled.entries) {
      if (previous.containsKey(hash)) continue;
      final proposal = _proposals.remove(hash);
      if (proposal == null) {
        quantusPrint('A proposal settled that was never seen broadcast: $hash');
        continue;
      }
      final multisig = _ref
          .read(multisigAccountsProvider)
          .value
          ?.where((msig) => msig.accountId == proposal.multisigAddress)
          .firstOrNull;
      if (multisig == null) {
        quantusPrint('Not notifying about a proposal in a multisig no longer in the wallet: $hash');
        continue;
      }
      final l10n = _ref.read(l10nProvider);
      final amount = _amountText(proposal.amount);
      switch (outcome) {
        case SendConfirmation.confirmed:
          _show(
            id: 'proposal_created_$hash',
            accountId: multisig.accountId,
            accountName: multisig.name,
            extrinsicHash: hash,
            intent: NotificationIntent.others,
            title: l10n.desktopNotificationProposalCreatedTitle,
            body: l10n.desktopNotificationProposalCreatedBody(amount, multisig.name),
          );
        case SendConfirmation.unconfirmed:
          _show(
            id: 'proposal_not_confirmed_$hash',
            accountId: multisig.accountId,
            accountName: multisig.name,
            extrinsicHash: hash,
            intent: NotificationIntent.others,
            title: l10n.desktopNotificationProposalNotConfirmedTitle,
            body: l10n.desktopNotificationProposalNotConfirmedBody(amount, multisig.name),
          );
        case SendConfirmation.pending:
          throw StateError('A proposal is settled as still pending: $hash');
      }
    }
  }

  /// Notifies about [send], of [amount].
  void _notifySend(
    PendingTransactionEvent send, {
    required BigInt amount,
    required String Function(AppLocalizations l10n, String amount) title,
    required String Function(AppLocalizations l10n, String amount, String account) body,
  }) =>
      _notifyFrom(send.from, id: send.id, extrinsicHash: send.extrinsicHash, amount: amount, title: title, body: body);

  /// Notifies about the send [id] from the account [from], when that account
  /// is still in the wallet.
  void _notifyFrom(
    String from, {
    required String id,
    required String? extrinsicHash,
    required BigInt amount,
    required String Function(AppLocalizations l10n, String amount) title,
    required String Function(AppLocalizations l10n, String amount, String account) body,
  }) {
    final account = _ref.read(accountsProvider).value?.where((a) => a.accountId == from).firstOrNull;
    if (account == null) {
      quantusPrint('Not notifying about a send from an account no longer in the wallet: $id');
      return;
    }
    final l10n = _ref.read(l10nProvider);
    final amountText = _amountText(amount);
    _show(
      id: 'send_$id',
      accountId: account.accountId,
      accountName: account.name,
      extrinsicHash: extrinsicHash,
      intent: NotificationIntent.sentTokens,
      title: title(l10n, amountText),
      body: body(l10n, amountText, account.name),
    );
  }

  String _amountText(BigInt amount) {
    final formatted = _ref.read(numberFormattingServiceProvider).formatBalance(amount, smartDecimals: 4);
    return _ref.read(l10nProvider).commonAmountBalance(formatted, AppConstants.tokenSymbol);
  }

  /// Shows a notification when the person wants it and the system allows it.
  void _show({
    required String id,
    required String accountId,
    required String accountName,
    required String? extrinsicHash,
    required NotificationIntent intent,
    required String title,
    required String body,
  }) {
    final config = _ref.read(notificationConfigProvider);
    if (!config.enabled || !config.isIntentEnabled(intent)) return;
    final status = _ref.read(desktopLocalNotificationsProvider);
    if (status is! NotificationsAllowed) {
      quantusPrint('Not notifying "$title": notifications are ${status.runtimeType}');
      return;
    }
    final notification = NotificationData(
      id: id,
      accountId: accountId,
      type: NotificationType.info,
      intent: intent,
      source: NotificationSource.local,
      title: title,
      message: body,
      accountName: accountName,
      timestamp: clock.now(),
      metadata: extrinsicHash == null ? null : {notificationHashKey: extrinsicHash},
      persistent: false,
    );
    _holdWhile(_showNow(notification));
  }

  Future<void> _showNow(NotificationData notification) async {
    try {
      await _ref.read(desktopLocalNotificationsProvider.notifier).showOrScheduleNotification(notification);
      if (!_ref.mounted) return;
      late final Timer settled;
      settled = Timer(settleDelay, () => _settling.remove(settled));
      _settling.add(settled);
    } catch (e) {
      quantusPrint('Showing a notification failed: $e');
      _ref.read(telemetryProvider).sendError('desktop_notification_show_failed', error: e);
    }
  }
}

final ownActivityNotificationsProvider = Provider<OwnActivityNotifications>(OwnActivityNotifications.new);
