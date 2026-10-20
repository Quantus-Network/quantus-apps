import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// How one history entry reads for the account on screen.
class TxPresentation {
  final TransactionEvent event;
  final String label;
  final String counterparty;
  final bool incoming;
  final bool pending;
  final BigInt amount;
  final BigInt? fee;

  const TxPresentation({
    required this.event,
    required this.label,
    required this.counterparty,
    required this.incoming,
    required this.pending,
    required this.amount,
    this.fee,
  });

  factory TxPresentation.of(TransactionEvent event, {required String accountId, required AppLocalizations l10n}) {
    final incoming = event.to == accountId && event.from != accountId;
    final self = event.to == accountId && event.from == accountId;
    final label = switch (event) {
      MinerRewardEvent() => l10n.accountMiningReward,
      ReversibleTransferEvent(status: ReversibleTransferStatus.SCHEDULED) => l10n.accountReversibleScheduled,
      ReversibleTransferEvent(status: ReversibleTransferStatus.CANCELLED) => l10n.accountReversibleCancelled,
      _ when self => l10n.accountSelfTransfer,
      _ when incoming => l10n.accountReceived,
      _ => l10n.accountSent,
    };
    return TxPresentation(
      event: event,
      label: label,
      counterparty: incoming ? event.from : event.to,
      incoming: incoming || event is MinerRewardEvent,
      pending: event is PendingTransactionEvent,
      amount: event.amount,
      fee: switch (event) {
        TransferEvent() => event.fee,
        PendingTransactionEvent() => event.fee,
        _ => null,
      },
    );
  }
}
