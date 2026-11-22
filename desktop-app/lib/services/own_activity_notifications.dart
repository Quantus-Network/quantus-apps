import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/providers/notification_click_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/pending_transaction_polling_service.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Notifies what this computer itself did, once the chain has had its say: a
/// Transparent send confirmed, failed or not seen in time, and a proposal
/// made here created or not seen in time.
///
/// What happens elsewhere (funds received, what other signers do) is for
/// remote notifications.
class OwnActivityNotifications {
  OwnActivityNotifications(this._ref) {
    _ref.listen(pendingTransactionsProvider, (_, sends) => _onSends(sends));
    _ref.listen(pendingMultisigProposalsProvider, (_, proposals) => _onProposals(proposals));
    _ref.listen(
      multisigProposalConfirmationsProvider,
      (previous, settled) => _onSettled(previous ?? const {}, settled),
    );
  }

  final Ref _ref;

  /// The broadcast sends being watched, by id, with when each was broadcast.
  final _sends = <String, ({PendingTransactionEvent send, DateTime broadcastAt})>{};

  /// The proposals broadcast from here, by the hash of the transaction each
  /// was sent in. Kept until their outcome is known: a created proposal
  /// leaves the pending proposals before that.
  final _proposals = <String, PendingMultisigProposalEvent>{};

  void _onSends(List<PendingTransactionEvent> sends) {
    final now = clock.now();
    for (final send in sends) {
      final watched = _sends[send.id];
      switch (send.transactionState) {
        case TransactionState.pending when watched == null:
          _sends[send.id] = (send: send, broadcastAt: now);
        case TransactionState.inHistory when watched != null:
          _sends.remove(send.id);
          unawaited(_notifySent(send));
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
  }) {
    final account = _ref.read(accountsProvider).value?.where((a) => a.accountId == send.from).firstOrNull;
    if (account == null) {
      quantusPrint('Not notifying about a send from an account no longer in the wallet: ${send.id}');
      return;
    }
    final l10n = _ref.read(l10nProvider);
    final amountText = _amountText(amount);
    _show(
      id: 'send_${send.id}',
      accountId: account.accountId,
      accountName: account.name,
      extrinsicHash: send.extrinsicHash,
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
    unawaited(_showNow(notification));
  }

  Future<void> _showNow(NotificationData notification) async {
    try {
      await _ref.read(desktopLocalNotificationsProvider.notifier).showOrScheduleNotification(notification);
    } catch (e) {
      quantusPrint('Showing a notification failed: $e');
      _ref.read(telemetryProvider).sendError('desktop_notification_show_failed', error: e);
    }
  }
}

final ownActivityNotificationsProvider = Provider<OwnActivityNotifications>(OwnActivityNotifications.new);
