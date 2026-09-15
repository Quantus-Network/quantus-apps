import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';

/// Testnets whose mining rewards can be claimed, oldest first.
enum TestnetChain {
  resonance('Resonance', 'Resonance'),
  schrodinger('Schrödinger', 'Schrodinger'),
  dirac('Dirac', 'Dirac'),
  planck('Planck', 'Planck');

  const TestnetChain(this.displayName, this._fileName);

  final String displayName;
  final String _fileName;

  /// The chain's trimmed "Miner Stats" export: one row per miner.
  String get rewardsAsset => 'assets/testnet_data/Miner Stats - $_fileName Testnet.csv';
}

/// One table row this wallet owns. Addresses changed format over the
/// testnets, so a wallet often owns several rows on one chain.
class AddressReward {
  final AirdropMatch match;
  final MinerReward reward;

  const AddressReward({required this.match, required this.reward});

  String get address => match.address;

  /// Whether the claim server accepts proofs for this address's era.
  bool get claimable => match.claimable;
}

/// What one wallet mined on one testnet and what that pays out.
class ChainRewards {
  final TestnetChain chain;
  final List<AddressReward> rows;

  const ChainRewards({required this.chain, required this.rows});

  int get blocksMined => rows.fold(0, (sum, r) => sum + r.reward.blocks);

  /// Payout across the rows that can actually be claimed today.
  int get rewardHundredths => rows.where((r) => r.claimable).fold(0, (sum, r) => sum + r.reward.rewardHundredths);

  bool get isEligible => rows.any((r) => r.claimable);

  List<AirdropMatch> get matches => [for (final r in rows) r.match];

  BigInt get rewardTokens => hundredthsToTokens(rewardHundredths);
}

BigInt hundredthsToTokens(int hundredths) => BigInt.from(hundredths) * BigInt.from(10).pow(AppConstants.decimals - 2);
