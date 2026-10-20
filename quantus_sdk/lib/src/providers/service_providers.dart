import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/utils/print.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());

final accountsServiceProvider = Provider<AccountsService>((ref) => AccountsService());

final chainHistoryServiceProvider = Provider<ChainHistoryService>((ref) => ChainHistoryService());

final substrateServiceProvider = Provider<SubstrateService>((ref) => SubstrateService());

final recentAddressesServiceProvider = Provider<RecentAddressesService>((ref) => RecentAddressesService());

final balancesServiceProvider = Provider<BalancesService>((ref) => BalancesService());

final humanReadableChecksumServiceProvider = Provider<HumanReadableChecksumService>(
  (ref) => HumanReadableChecksumService(),
);

final checksumNameProvider = FutureProvider.family<String, String>((ref, address) async {
  final name = await ref.watch(humanReadableChecksumServiceProvider).getHumanReadableName(address);
  return name ?? '';
});

final balanceProviderFamily = FutureProvider.family<BigInt, String>((ref, accountId) async {
  final substrateService = ref.watch(substrateServiceProvider);
  quantusPrint('query balance for $accountId');
  return substrateService.queryBalance(accountId);
});

final isBalanceHiddenProvider = StateNotifierProvider<IsBalanceHiddenNotifier, bool>((ref) {
  return IsBalanceHiddenNotifier(ref.watch(settingsServiceProvider));
});

class IsBalanceHiddenNotifier extends StateNotifier<bool> {
  final SettingsService _settingsService;

  IsBalanceHiddenNotifier(this._settingsService) : super(_settingsService.isBalanceHidden());

  Future<void> setIsBalanceHidden(bool value) async {
    await _settingsService.setBalanceHidden(value);
    state = value;
  }
}
