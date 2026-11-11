import 'package:quantus_sdk/quantus_sdk.dart';

/// Immutable key used to parameterise the filtered-transactions provider family.
///
/// Riverpod family keys must implement [==] and [hashCode]; this class
/// satisfies that requirement so every unique (accountIds, filter) combination
/// gets its own isolated [StateNotifier].
class FilteredTransactionsParams {
  final List<String> accountIds;
  final TransactionFilter filter;

  const FilteredTransactionsParams({required this.accountIds, required this.filter});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilteredTransactionsParams && identical(other.accountIds, accountIds) && other.filter == filter;

  @override
  int get hashCode => Object.hash(Object.hashAll(accountIds), filter);
}
