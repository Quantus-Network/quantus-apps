import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';

/// Debug stand-in for [MiningRewardsService]: canned rewards per outcome and a
/// submission that never reaches the server or the stored claim. Picked on the
/// Airdrop entry screen in debug builds.
class DebugMiningRewardsService extends MiningRewardsService {
  static const outcomes = ['mixed', 'some', 'below', 'none', 'claimed', 'fail', 'partial'];

  final String outcome;

  DebugMiningRewardsService({required super.settings, required this.outcome});

  /// Under the claimed outcome only the first wallet has claimed, so the entry
  /// page shows both states side by side.
  static AirdropClaimRecord? claimRecord(String outcome, int walletIndex) => outcome == 'claimed' && walletIndex == 0
      ? AirdropClaimRecord(
          claimedAt: DateTime(2026, 9, 16),
          rewardHundredths: 12180,
          claimAccount: AppConstants.debugTestAddress,
          accountName: 'Account 1',
        )
      : null;

  /// (blocks, reward hundredths) per owned address, per chain.
  static const Map<String, Map<TestnetChain, List<(int, int)>>> _rows = {
    'mixed': {
      TestnetChain.resonance: [(500, 1833), (11, 10)],
      TestnetChain.schrodinger: [(5200, 7304), (79, 10)],
      TestnetChain.dirac: [(837, 620)],
      TestnetChain.planck: [(5915, 2403)],
    },
    'some': {
      TestnetChain.dirac: [(2104, 1187)],
      TestnetChain.planck: [(418, 644)],
    },
    'below': {
      TestnetChain.resonance: [(92, 10)],
      TestnetChain.dirac: [(2104, 10)],
      TestnetChain.planck: [(418, 10)],
    },
  };

  @override
  Future<ChainRewards> checkChain(int walletIndex, TestnetChain chain) async {
    await Future<void>.delayed(Duration(milliseconds: 900 * (chain.index + 1)));
    final rows = _rows[outcome == 'fail' || outcome == 'partial' ? 'mixed' : outcome]?[chain] ?? const [];
    return ChainRewards(
      chain: chain,
      rows: [
        for (final (i, (blocks, hundredths)) in rows.indexed)
          AddressReward(
            match: AirdropMatch(
              address: '${'qz${chain.name}$i'.padRight(48, 'x')}$i',
              kind: chain == TestnetChain.planck ? 'wormhole' : 'dilithium',
              scheme: 'debug',
              claimable: true,
              source: 'debug',
            ),
            reward: MinerReward(blocks: blocks, rewardHundredths: hundredths),
          ),
      ],
    );
  }

  @override
  Future<void> submitClaims({
    required int walletIndex,
    required List<ChainRewards> rewards,
    required ClaimDestination destination,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (outcome == 'fail') {
      throw const AirdropClaimFailure(
        submitted: 0,
        total: 5,
        causes: {'all': 'debugMiningRewards: server unreachable'},
      );
    }
    if (outcome == 'partial') {
      throw const AirdropClaimFailure(submitted: 3, total: 5, causes: {'two': 'debugMiningRewards: timed out'});
    }
  }
}
