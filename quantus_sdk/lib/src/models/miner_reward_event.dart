import 'package:quantus_sdk/quantus_sdk.dart';

/// Represents a mining reward that was credited to a miner account.
///
/// For the purpose of displaying in the transactions list we model this as a
/// `TransactionEvent` where the [from] field is the constant string
/// "Mining Reward" so that existing UI can show "from Mining Reward" for the
/// subtitle. The user specifically asked for the subtitle to read just
/// "Mining Reward" (without the "from" prefix) – that UI change will be made
/// separately. For now keeping the constant makes integration minimal and
/// backwards-compatible.
class MinerRewardEvent extends TransactionEvent {
  static const String miningRewardSource = 'Mining Reward';

  MinerRewardEvent({
    required super.id,
    required String miner,
    required BigInt reward,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
  }) : super(from: miningRewardSource, to: miner, amount: reward);

  factory MinerRewardEvent.fromJson(Map<String, dynamic> json) {
    final block = json['block'] as Map<String, dynamic>?;
    final blockHeight = block?['height'] as int? ?? 0;
    final blockHash = block?['hash'] as String? ?? '';

    return MinerRewardEvent(
      id: json['id'] as String,
      miner: json['miner']?['id'] as String? ?? '',
      reward: BigInt.parse(json['reward'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      blockNumber: blockHeight,
      blockHash: blockHash,
    );
  }

  String get miner => to; // Alias for clarity
  BigInt get reward => amount;

  @override
  String toString() {
    return 'MinerReward{id: $id, miner: $miner, reward: $reward, timestamp: $timestamp, blockNumber: $blockNumber}';
  }
}
