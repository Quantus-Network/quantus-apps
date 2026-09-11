import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mainnet_migration_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final mainnetMigrationServiceProvider = Provider<MainnetMigrationService>(
  (ref) => MainnetMigrationService(
    settings: ref.watch(settingsServiceProvider),
    hdWallet: ref.watch(hdWalletServiceProvider),
  ),
);

/// Debug builds show the notice on every launch; its checking page then picks
/// the testnet outcome at runtime, no real testnet data needed.
final debugMainnetMigrationProvider = Provider<bool>((_) => kDebugMode && AppConstants.debugMainnetMigration);

/// A picked outcome stands in for the testnet check; null runs the real one.
final forcedTestnetOutcomeProvider = StateProvider<String?>((_) => null);

const debugTestnetOutcomes = ['miner', 'holder', 'newcomer', 'error'];

/// Whether the notice is still due.
final mainnetMigrationPendingProvider = Provider<bool>(
  (ref) => ref.watch(debugMainnetMigrationProvider) || ref.watch(mainnetMigrationServiceProvider).isPending(),
);

/// The one-shot check is not retried: the unreachable page is written for it,
/// and a retry would flip it back to the checking page.
final testnetStatusProvider = FutureProvider<TestnetStatus>((ref) async {
  final forced = ref.watch(forcedTestnetOutcomeProvider);
  if (forced != null) return _forcedStatus(forced);
  try {
    return await ref.watch(mainnetMigrationServiceProvider).checkTestnetStatus();
  } catch (e) {
    quantusPrint('Testnet status check failed: $e');
    rethrow;
  }
}, retry: (_, _) => null);

TestnetStatus _forcedStatus(String outcome) => switch (outcome) {
  'miner' => TestnetStatus(blocksMined: 1234, balance: BigInt.zero),
  'holder' => TestnetStatus(blocksMined: 0, balance: BigInt.from(7) * BigInt.from(10).pow(AppConstants.decimals)),
  'newcomer' => TestnetStatus(blocksMined: 0, balance: BigInt.zero),
  'error' => throw Exception('debugMainnetMigration: testnet unreachable'),
  _ => throw ArgumentError.value(outcome, 'debugMainnetMigration'),
};
