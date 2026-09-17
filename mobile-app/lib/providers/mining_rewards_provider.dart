import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/debug_mining_rewards_service.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Debug builds offer an outcome picker on the Airdrop entry screen.
final debugMiningRewardsProvider = Provider<bool>((_) => kDebugMode && AppConstants.debugMiningRewards);

/// A picked outcome swaps in canned rewards; null runs the real check.
final forcedRewardsOutcomeProvider = StateProvider<String?>((_) => null);

final miningRewardsServiceProvider = Provider<MiningRewardsService>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  final forced = ref.watch(forcedRewardsOutcomeProvider);
  return forced == null
      ? MiningRewardsService(settings: settings)
      : DebugMiningRewardsService(settings: settings, outcome: forced);
});

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

/// The claim this wallet already submitted, if any.
final airdropClaimRecordProvider = Provider.family<AirdropClaimRecord?, int>((ref, walletIndex) {
  final forced = ref.watch(forcedRewardsOutcomeProvider);
  if (forced != null) return DebugMiningRewardsService.claimRecord(forced);
  return ref.watch(settingsServiceProvider).getAirdropClaim(walletIndex);
});
