// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i6;

import '../../primitive_types/h256.dart' as _i4;
import '../../sp_runtime/multiaddress/multi_address.dart' as _i5;
import '../delay_policy.dart' as _i3;

/// Contains a variant per dispatchable extrinsic that this pallet has.
abstract class Call {
  const Call();

  factory Call.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $CallCodec codec = $CallCodec();

  static const $Call values = $Call();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, Map<String, dynamic>> toJson();
}

class $Call {
  const $Call();

  SetReversibility setReversibility({
    int? delay,
    required _i3.DelayPolicy policy,
  }) {
    return SetReversibility(
      delay: delay,
      policy: policy,
    );
  }

  Cancel cancel({required _i4.H256 txId}) {
    return Cancel(txId: txId);
  }

  ExecuteTransfer executeTransfer({required _i4.H256 txId}) {
    return ExecuteTransfer(txId: txId);
  }

  ScheduleTransfer scheduleTransfer({
    required _i5.MultiAddress dest,
    required BigInt amount,
  }) {
    return ScheduleTransfer(
      dest: dest,
      amount: amount,
    );
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return SetReversibility._decode(input);
      case 1:
        return Cancel._decode(input);
      case 2:
        return ExecuteTransfer._decode(input);
      case 3:
        return ScheduleTransfer._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Call value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case SetReversibility:
        (value as SetReversibility).encodeTo(output);
        break;
      case Cancel:
        (value as Cancel).encodeTo(output);
        break;
      case ExecuteTransfer:
        (value as ExecuteTransfer).encodeTo(output);
        break;
      case ScheduleTransfer:
        (value as ScheduleTransfer).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case SetReversibility:
        return (value as SetReversibility)._sizeHint();
      case Cancel:
        return (value as Cancel)._sizeHint();
      case ExecuteTransfer:
        return (value as ExecuteTransfer)._sizeHint();
      case ScheduleTransfer:
        return (value as ScheduleTransfer)._sizeHint();
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Enable reversibility for the calling account with a specified delay, or disable it.
///
/// - `delay`: The time (in milliseconds) after submission before the transaction executes.
///  If `None`, reversibility is disabled for the account.
///  If `Some`, must be >= `MinDelayPeriod`.
class SetReversibility extends Call {
  const SetReversibility({
    this.delay,
    required this.policy,
  });

  factory SetReversibility._decode(_i1.Input input) {
    return SetReversibility(
      delay: const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
      policy: _i3.DelayPolicy.codec.decode(input),
    );
  }

  /// Option<BlockNumberFor<T>>
  final int? delay;

  /// DelayPolicy
  final _i3.DelayPolicy policy;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'set_reversibility': {
          'delay': delay,
          'policy': policy.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size =
        size + const _i1.OptionCodec<int>(_i1.U32Codec.codec).sizeHint(delay);
    size = size + _i3.DelayPolicy.codec.sizeHint(policy);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      delay,
      output,
    );
    _i3.DelayPolicy.codec.encodeTo(
      policy,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is SetReversibility &&
          other.delay == delay &&
          other.policy == policy;

  @override
  int get hashCode => Object.hash(
        delay,
        policy,
      );
}

/// Cancel a pending reversible transaction scheduled by the caller.
///
/// - `tx_id`: The unique identifier of the transaction to cancel.
class Cancel extends Call {
  const Cancel({required this.txId});

  factory Cancel._decode(_i1.Input input) {
    return Cancel(txId: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::Hash
  final _i4.H256 txId;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'cancel': {'txId': txId.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i4.H256Codec().sizeHint(txId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      txId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Cancel &&
          _i6.listsEqual(
            other.txId,
            txId,
          );

  @override
  int get hashCode => txId.hashCode;
}

/// Called by the Scheduler to finalize the scheduled task/call
///
/// - `tx_id`: The unique id of the transaction to finalize and dispatch.
class ExecuteTransfer extends Call {
  const ExecuteTransfer({required this.txId});

  factory ExecuteTransfer._decode(_i1.Input input) {
    return ExecuteTransfer(txId: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::Hash
  final _i4.H256 txId;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'execute_transfer': {'txId': txId.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i4.H256Codec().sizeHint(txId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      txId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ExecuteTransfer &&
          _i6.listsEqual(
            other.txId,
            txId,
          );

  @override
  int get hashCode => txId.hashCode;
}

/// Schedule a transaction for delayed execution.
class ScheduleTransfer extends Call {
  const ScheduleTransfer({
    required this.dest,
    required this.amount,
  });

  factory ScheduleTransfer._decode(_i1.Input input) {
    return ScheduleTransfer(
      dest: _i5.MultiAddress.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// <<T as frame_system::Config>::Lookup as StaticLookup>::Source
  final _i5.MultiAddress dest;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'schedule_transfer': {
          'dest': dest.toJson(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i5.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i5.MultiAddress.codec.encodeTo(
      dest,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ScheduleTransfer && other.dest == dest && other.amount == amount;

  @override
  int get hashCode => Object.hash(
        dest,
        amount,
      );
}
