import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/open_proposal_entry.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';

class ActivityDateGroup<T> {
  final String label;
  final List<T> items;

  const ActivityDateGroup({required this.label, required this.items});
}

List<ActivityDateGroup<TransactionEvent>> groupTransactionsByDate(
  List<TransactionEvent> transactions,
  AppLocalizations l10n,
  String localeName,
) {
  return _groupByDate(transactions, l10n, localeName, (tx) => tx.timestamp);
}

List<ActivityDateGroup<OpenProposalEntry>> groupOpenProposalsByDate(
  List<OpenProposalEntry> entries,
  AppLocalizations l10n,
  String localeName,
) {
  return _groupByDate(entries, l10n, localeName, (entry) => entry.timestamp);
}

List<ActivityDateGroup<MultisigProposal>> groupPastProposalsByDate(
  List<MultisigProposal> proposals,
  AppLocalizations l10n,
  String localeName,
) {
  return _groupByDate(proposals, l10n, localeName, (proposal) => proposal.createdAt);
}

List<ActivityDateGroup<T>> _groupByDate<T>(
  List<T> items,
  AppLocalizations l10n,
  String localeName,
  DateTime Function(T) timestampOf,
) {
  final groups = <String, List<T>>{};
  final labelMap = <String, String>{};

  for (final item in items) {
    final timestamp = timestampOf(item);
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final key = '${day.year}-${day.month}-${day.day}';
    groups.putIfAbsent(key, () => []);
    groups[key]!.add(item);
    labelMap.putIfAbsent(key, () => dateGroupLabel(timestamp, l10n, localeName));
  }

  return groups.entries
      .map((e) => ActivityDateGroup<T>(label: labelMap[e.key]!.toUpperCase(), items: e.value))
      .toList();
}
