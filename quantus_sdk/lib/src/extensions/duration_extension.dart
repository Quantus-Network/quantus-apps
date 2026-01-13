import 'package:quantus_sdk/generated/schrodinger/types/qp_scheduler/block_number_or_timestamp.dart' as qp;

extension DurationToTimestampExtension on Duration {
  qp.Timestamp get qpTimestamp => qp.Timestamp(BigInt.from(inSeconds) * BigInt.from(1000));

  static Duration fromQpTimestamp(qp.Timestamp timestamp) => Duration(seconds: timestamp.value0.toInt() ~/ 1000);
}
