import 'package:quantus_sdk/quantus_sdk.dart';

/// Testnets whose mining rewards can be claimed, oldest first.
enum TestnetChain {
  resonance('Resonance', 'Resonance'),
  schrodinger('Schrödinger', 'Schrodinger'),
  dirac('Dirac', 'Dirac'),
  planck('Planck', 'Planck');

  const TestnetChain(this.displayName, this._fileName);

  final String displayName;
  final String _fileName;

  /// The chain's "Miner Stats" export: one row per miner with blocks and payout.
  String get rewardsAsset => 'assets/testnet_data/Miner Stats - $_fileName Testnet.csv';
}

/// One miner's row in a chain's rewards table.
class MinerReward {
  final int blocks;
  final int rewardHundredths;

  const MinerReward({required this.blocks, required this.rewardHundredths});
}

/// What one wallet mined on one testnet and what that pays out, summed over
/// every table row the wallet owns.
class ChainRewards {
  final TestnetChain chain;
  final int blocksMined;
  final int rewardHundredths;
  final List<AirdropMatch> matches;

  const ChainRewards({
    required this.chain,
    required this.blocksMined,
    required this.rewardHundredths,
    required this.matches,
  });

  bool get isEligible => matches.isNotEmpty;

  BigInt get rewardTokens => hundredthsToTokens(rewardHundredths);
}

BigInt hundredthsToTokens(int hundredths) => BigInt.from(hundredths) * BigInt.from(10).pow(AppConstants.decimals - 2);
