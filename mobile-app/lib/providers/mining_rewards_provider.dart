import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final miningRewardsServiceProvider = Provider<MiningRewardsService>(
  (ref) => MiningRewardsService(settings: ref.watch(settingsServiceProvider)),
);

typedef ChainCheck = ({int walletIndex, TestnetChain chain});

/// One-shot per chain: a failed check stays an error until the row retries it.
final chainEligibilityProvider = FutureProvider.autoDispose.family<ChainRewards, ChainCheck>((ref, check) async {
  try {
    return await ref.watch(miningRewardsServiceProvider).checkChain(check.walletIndex, check.chain);
  } catch (e) {
    quantusPrint('Mining rewards check on ${check.chain.displayName} failed: $e');
    rethrow;
  }
}, retry: (_, _) => null);
