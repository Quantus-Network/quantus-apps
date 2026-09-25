import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Whether the notice is still due.
final mainnetMigrationPendingProvider = Provider<bool>((ref) {
  if (AppConstants.runOnTestnet) return false;
  return ref.watch(mainnetMigrationServiceProvider).isPending();
});

/// The one-shot check is not retried: the unreachable page is written for it,
/// and a retry would flip it back to the checking page.
final testnetStatusProvider = FutureProvider<TestnetStatus>((ref) async {
  try {
    return await ref.watch(mainnetMigrationServiceProvider).checkTestnetStatus();
  } catch (e) {
    quantusPrint('Testnet status check failed: $e');
    rethrow;
  }
}, retry: (_, _) => null);
