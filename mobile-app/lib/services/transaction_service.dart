import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/transaction_role.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref);
});

enum TransactionViewType { normal, reversible, guardianIntercept }

class TransactionDetailViewConfig {
  final TransactionViewType type;
  final EntrustedAccount? entrustedAccount;

  const TransactionDetailViewConfig({required this.type, this.entrustedAccount});

  static const normal = TransactionDetailViewConfig(type: TransactionViewType.normal);
}

class TransactionService {
  final Ref _ref;

  TransactionService(this._ref);

  /// Combines and deduplicates transactions from multiple sources
  /// Priority order: pending -> reversible -> other
  /// Duplicates are removed based on transaction ID
  List<TransactionEvent> combineAndDeduplicateTransactions({
    required Set<String> pendingCancellationIds,
    required List<PendingTransactionEvent> pendingTransactions,
    required List<PendingMultisigCreationEvent> pendingMultisigCreations,
    required List<PendingMultisigProposalEvent> pendingMultisigProposals,
    required List<PendingMultisigExecutionEvent> pendingMultisigExecutions,
    required List<PendingMultisigCancellationEvent> pendingMultisigCancellations,
    required List<ReversibleTransferEvent> scheduledReversibleTransfers,
    required List<TransactionEvent> otherTransfers,
  }) {
    final seenIds = <String>{};
    final seenProposalKeys = <String>{};
    final seenExecutionKeys = <String>{};
    final seenCancellationKeys = <String>{};
    final List<TransactionEvent> result = [];

    for (final creation in pendingMultisigCreations) {
      if (seenIds.add(creation.id)) {
        result.add(creation);
      }
    }

    for (final proposal in pendingMultisigProposals) {
      final key = proposal.activityDedupKey;
      if (seenProposalKeys.add(key) && seenIds.add(proposal.id)) {
        result.add(proposal);
      }
    }

    for (final execution in pendingMultisigExecutions) {
      final key = execution.activityDedupKey;
      if (seenExecutionKeys.add(key) && seenIds.add(execution.id)) {
        result.add(execution);
      }
    }

    for (final cancellation in pendingMultisigCancellations) {
      final key = cancellation.activityDedupKey;
      if (seenCancellationKeys.add(key) && seenIds.add(cancellation.id)) {
        result.add(cancellation);
      }
    }

    // Add pending transactions that haven't not failed first (highest priority)
    for (final transaction in pendingTransactions) {
      if (transaction.transactionState == TransactionState.failed) {
        otherTransfers.add(transaction);
      } else if (seenIds.add(transaction.id)) {
        if (transaction.isReversible && pendingCancellationIds.contains(transaction.id)) {
          result.add(transaction.copyWith(status: ReversibleTransferStatus.CANCELLED));
        } else {
          result.add(transaction);
        }
      }
    }

    // Add reversible transfers (medium priority)
    for (final transaction in scheduledReversibleTransfers) {
      if (transaction.status == ReversibleTransferStatus.SCHEDULED) {
        if (seenIds.add(transaction.id)) {
          if (pendingCancellationIds.contains(transaction.id)) {
            result.add(transaction.copyWith(status: ReversibleTransferStatus.CANCELLED));
          } else {
            result.add(transaction);
          }
        }
      }
    }

    // Add other transfers (lowest priority)
    otherTransfers.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (final transaction in otherTransfers) {
      if (transaction is MultisigProposalCreatedEvent) {
        final key = transaction.activityDedupKey;
        if (seenProposalKeys.contains(key)) {
          result.removeWhere((e) => e is PendingMultisigProposalEvent && e.activityDedupKey == key);
        }
        seenProposalKeys.add(key);
      }
      if (transaction is MultisigProposalExecutedEvent) {
        final key = transaction.activityDedupKey;
        if (seenExecutionKeys.contains(key)) {
          result.removeWhere((e) => e is PendingMultisigExecutionEvent && e.activityDedupKey == key);
        }
        seenExecutionKeys.add(key);
      }
      if (transaction is MultisigProposalCancelledEvent) {
        final key = transaction.activityDedupKey;
        if (seenCancellationKeys.contains(key)) {
          result.removeWhere((e) => e is PendingMultisigCancellationEvent && e.activityDedupKey == key);
        }
        seenCancellationKeys.add(key);
      }
      if (seenIds.add(transaction.id)) {
        result.add(transaction);
      }
    }

    return result;
  }

  TransactionRole getTransactionRole(TransactionEvent transaction, {List<String>? accountIds}) {
    final accounts = accountIds ?? (_ref.read(accountsProvider).value?.map((acc) => acc.accountId).toList() ?? []);

    final isFrom = accounts.contains(transaction.from);
    final isTo = accounts.contains(transaction.to);

    if (isFrom && isTo) {
      return TransactionRole.both;
    } else if (isFrom) {
      return TransactionRole.sender;
    } else {
      return TransactionRole.receiver;
    }
  }

  /// Routes a locally generated notification payload (serialized notification
  /// metadata) to the transaction detail sheet. Only safe for app-generated
  /// data — untrusted FCM push payloads must go through
  /// [navigateToTransactionFromPushPayloadIfPossible] instead.
  void navigateToTransactionFromPayloadIfPossible(Map<String, dynamic> json) {
    final event = deserializeTxEventFromJsonIfPossible(json);

    if (event != null) {
      _ref.read(transactionIntentProvider.notifier).state = event;
    }
  }

  /// Routes a transfer push payload to the transaction detail sheet.
  ///
  /// The payload is only a hint — the transaction is re-fetched from the
  /// indexer via [resolveTransactionFromPushPayload] first; when it cannot be
  /// verified, nothing is shown.
  Future<void> navigateToTransactionFromPushPayloadIfPossible(Map<String, dynamic> json) async {
    final event = await resolveTransactionFromPushPayload(json);

    if (event != null) {
      _ref.read(transactionIntentProvider.notifier).state = event;
    }
  }

  /// Resolves a transfer push payload to the real on-chain transaction.
  ///
  /// Push payloads are untrusted — anyone able to send to the device's FCM
  /// token can fabricate sender/amount fields — so the payload is treated as
  /// a mere hint: only its extrinsic hash is used to re-fetch the transaction
  /// from the indexer, and nothing else from the payload is ever rendered.
  /// Fails closed (returns null) when the payload carries no usable hash, the
  /// type is unsupported, the lookup errors, or the indexer has no matching
  /// transaction.
  Future<TransactionEvent?> resolveTransactionFromPushPayload(Map<String, dynamic> json) async {
    final txType = json['type'];
    final bool isReversible;
    if (txType == EventType.TRANSFER.name) {
      isReversible = false;
    } else if (txType == EventType.REVERSIBLE_TRANSFER.name) {
      isReversible = true;
    } else {
      return null;
    }

    final extrinsicHash = json['extrinsicHash'];
    if (extrinsicHash is! String || extrinsicHash.isEmpty) return null;

    try {
      return await _ref
          .read(chainHistoryServiceProvider)
          .searchByExtrinsicHash(extrinsicHash: extrinsicHash, isReversible: isReversible);
    } catch (e, st) {
      debugPrint('Failed resolving push payload transaction $extrinsicHash: $e');
      TelemetryService().sendError('Failed resolving push payload transaction', error: e, stackTrace: st);
      return null;
    }
  }

  /// Routes a multisig proposal push payload to the proposal intent provider.
  ///
  /// Recognizes the payload by the presence of its `multisig`/`proposalId`
  /// identifiers, so it works whether or not the backend includes a `type`
  /// field. Returns true when the payload was a proposal notification so callers
  /// can skip the transaction deserialization path. Actual navigation (selecting
  /// the multisig and opening the detail sheet) happens in the UI layer that
  /// listens to [proposalIntentProvider].
  bool navigateToProposalFromPayloadIfPossible(Map<String, dynamic> json) {
    final intent = ProposalIntent.tryParse(json);
    if (intent == null) return false;

    _ref.read(proposalIntentProvider.notifier).state = intent;
    return true;
  }

  /// Deserializes app-generated transaction JSON (e.g. notification metadata
  /// written by this app). Must NOT be used on untrusted data such as FCM
  /// push payloads — those are spoofable; use [resolveTransactionFromPushPayload]
  /// instead.
  TransactionEvent? deserializeTxEventFromJsonIfPossible(dynamic json) {
    final txType = json['type'];
    TransactionEvent? event;

    try {
      if (txType == EventType.TRANSFER.name) {
        event = TransferEvent.fromJson(json);
      } else if (txType == EventType.REVERSIBLE_TRANSFER.name) {
        event = ReversibleTransferEvent.deserializeFromJson(json);
      } else if (txType == EventType.PENDING_TRANSACTION.name) {
        event = PendingTransactionEvent.fromJson(json);
      }
    } catch (e) {
      debugPrint('Failed deserializing $txType event: $e');
      TelemetryService().sendError(
        'Failed deserializing $txType event',
        error: e.runtimeType.toString(),
        stackTrace: StackTrace.current,
      );
    }

    return event;
  }

  /// Basically deciding whether or not to show a reversible or intercept user interface,
  /// or whether to just show a normal transaction detail view.
  static TransactionDetailViewConfig getTransactionDetailViewConfig({
    required TransactionEvent transaction,
    required TransactionRole role,
    required DisplayAccount? activeAccount,
  }) {
    if (transaction is! ReversibleTransferEvent) {
      return TransactionDetailViewConfig.normal;
    }

    final isScheduled = transaction.status == ReversibleTransferStatus.SCHEDULED;
    final isCancelled = transaction.status == ReversibleTransferStatus.CANCELLED;
    // Reversible transaction UX is shown for scheduled transactions, so user can intercept / revert them.
    // It is also shown for canceled transactions, showing a "this transaction was canceled/intercepted/reverted" message.
    final showReversibleTransactionUX = isScheduled || isCancelled;
    final isActorRole = role == TransactionRole.sender || role == TransactionRole.both;

    if (!showReversibleTransactionUX || !isActorRole) {
      return TransactionDetailViewConfig.normal;
    }

    if (activeAccount is EntrustedDisplayAccount) {
      return TransactionDetailViewConfig(
        type: TransactionViewType.guardianIntercept,
        entrustedAccount: activeAccount.account,
      );
    }

    return const TransactionDetailViewConfig(type: TransactionViewType.reversible);
  }
}
