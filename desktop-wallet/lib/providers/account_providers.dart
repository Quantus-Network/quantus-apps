import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// The account the screens show: the active one, else the first imported.
/// Null while accounts load or when none is imported.
final currentAccountProvider = Provider<Account?>((ref) {
  final accounts = ref.watch(accountsProvider).value;
  if (accounts == null || accounts.isEmpty) return null;
  final active = ref.watch(activeAccountProvider).value;
  if (active is RegularAccount && accounts.any((a) => a.accountId == active.account.accountId)) {
    return active.account;
  }
  return accounts.first;
});

final numberFormattingServiceProvider = Provider<NumberFormattingService>(
  (ref) => NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal),
);

final localeNumberConfigProvider = Provider<LocaleNumberConfig>((ref) => LocaleNumberConfig.dotDecimal);
