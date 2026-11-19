import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/sync_status_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/multisig_providers.dart';

/// Whether the app was built for the test network, which the footer names
/// in place of Mainnet. Tests set it.
final isTestnetProvider = Provider<bool>((ref) => AppConstants.runOnTestnet);

/// The chain's latest block, read again each time the wallet syncs; null
/// until it is first read, or while it cannot be read.
final latestBlockProvider = Provider<int?>((ref) {
  ref.listen(
    syncStatusProvider.select((status) => status.lastSyncedAt),
    (_, _) => ref.invalidate(multisigCurrentBlockProvider),
  );
  return ref.watch(multisigCurrentBlockProvider).value;
});
