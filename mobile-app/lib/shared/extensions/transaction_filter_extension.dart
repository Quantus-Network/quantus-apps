import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

extension TransactionFilterLabel on TransactionFilter {
  String filterLabel(AppLocalizations l10n) => switch (this) {
    TransactionFilter.all => l10n.activityFilterAll,
    TransactionFilter.send => l10n.activityFilterSend,
    TransactionFilter.receive => l10n.activityFilterReceive,
  };
}