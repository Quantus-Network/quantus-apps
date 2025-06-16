// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i8;

import '../../primitive_types/h256.dart' as _i6;
import '../../qp_scheduler/block_number_or_timestamp.dart' as _i3;
import '../../sp_core/crypto/account_id32.dart' as _i5;
import '../../sp_runtime/multiaddress/multi_address.dart' as _i7;
import '../delay_policy.dart' as _i4;

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
    _i3.BlockNumberOrTimestamp? delay,
    required _i4.DelayPolicy policy,
    _i5.AccountId32? reverser,
  }) {
    return SetReversibility(
      delay: delay,
      policy: policy,
      reverser: reverser,
    );
  }

  Cancel cancel({required _i6.H256 txId}) {
    return Cancel(txId: txId);
  }

  ExecuteTransfer executeTransfer({required _i6.H256 txId}) {
    return ExecuteTransfer(txId: txId);
  }

  ScheduleTransfer scheduleTransfer({
    required _i7.MultiAddress dest,
    required BigInt amount,
  }) {
    return ScheduleTransfer(
      dest: dest,
      amount: amount,
    );
  }

  ScheduleTransferWithDelay scheduleTransferWithDelay({
    required _i7.MultiAddress dest,
    required BigInt amount,
    required _i3.BlockNumberOrTimestamp delay,
  }) {
    return ScheduleTransferWithDelay(
      dest: dest,
      amount: amount,
      delay: delay,
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
      case 4:
        return ScheduleTransferWithDelay._decode(input);
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
      case ScheduleTransferWithDelay:
        (value as ScheduleTransferWithDelay).encodeTo(output);
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
      case ScheduleTransferWithDelay:
        return (value as ScheduleTransferWithDelay)._sizeHint();
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
    this.reverser,
  });

  factory SetReversibility._decode(_i1.Input input) {
    return SetReversibility(
      delay: const _i1.OptionCodec<_i3.BlockNumberOrTimestamp>(
              _i3.BlockNumberOrTimestamp.codec)
          .decode(input),
      policy: _i4.DelayPolicy.codec.decode(input),
      reverser: const _i1.OptionCodec<_i5.AccountId32>(_i5.AccountId32Codec())
          .decode(input),
    );
  }

  /// Option<BlockNumberOrTimestampOf<T>>
  final _i3.BlockNumberOrTimestamp? delay;

  /// DelayPolicy
  final _i4.DelayPolicy policy;

  /// Option<T::AccountId>
  final _i5.AccountId32? reverser;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'set_reversibility': {
          'delay': delay?.toJson(),
          'policy': policy.toJson(),
          'reverser': reverser?.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.OptionCodec<_i3.BlockNumberOrTimestamp>(
                _i3.BlockNumberOrTimestamp.codec)
            .sizeHint(delay);
    size = size + _i4.DelayPolicy.codec.sizeHint(policy);
    size = size +
        const _i1.OptionCodec<_i5.AccountId32>(_i5.AccountId32Codec())
            .sizeHint(reverser);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.OptionCodec<_i3.BlockNumberOrTimestamp>(
            _i3.BlockNumberOrTimestamp.codec)
        .encodeTo(
      delay,
      output,
    );
    _i4.DelayPolicy.codec.encodeTo(
      policy,
      output,
    );
    const _i1.OptionCodec<_i5.AccountId32>(_i5.AccountId32Codec()).encodeTo(
      reverser,
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
          other.policy == policy &&
          other.reverser == reverser;

  @override
  int get hashCode => Object.hash(
        delay,
        policy,
        reverser,
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
  final _i6.H256 txId;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'cancel': {'txId': txId.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i6.H256Codec().sizeHint(txId);
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
          _i8.listsEqual(
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
  final _i6.H256 txId;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'execute_transfer': {'txId': txId.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i6.H256Codec().sizeHint(txId);
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
          _i8.listsEqual(
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
      dest: _i7.MultiAddress.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// <<T as frame_system::Config>::Lookup as StaticLookup>::Source
  final _i7.MultiAddress dest;

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
    size = size + _i7.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i7.MultiAddress.codec.encodeTo(
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

/// Schedule a transaction for delayed execution with a custom, one-time delay.
///
/// This can only be used by accounts that have *not* set up a persistent
/// reversibility configuration with `set_reversibility`.
///
/// - `delay`: The time (in blocks or milliseconds) before the transaction executes.
class ScheduleTransferWithDelay extends Call {
  const ScheduleTransferWithDelay({
    required this.dest,
    required this.amount,
    required this.delay,
  });

  factory ScheduleTransferWithDelay._decode(_i1.Input input) {
    return ScheduleTransferWithDelay(
      dest: _i7.MultiAddress.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      delay: _i3.BlockNumberOrTimestamp.codec.decode(input),
    );
  }

  /// <<T as frame_system::Config>::Lookup as StaticLookup>::Source
  final _i7.MultiAddress dest;

  /// BalanceOf<T>
  final BigInt amount;

  /// BlockNumberOrTimestampOf<T>
  final _i3.BlockNumberOrTimestamp delay;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'schedule_transfer_with_delay': {
          'dest': dest.toJson(),
          'amount': amount,
          'delay': delay.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i7.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + _i3.BlockNumberOrTimestamp.codec.sizeHint(delay);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    _i7.MultiAddress.codec.encodeTo(
      dest,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
    _i3.BlockNumberOrTimestamp.codec.encodeTo(
      delay,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ScheduleTransferWithDelay &&
          other.dest == dest &&
          other.amount == amount &&
          other.delay == delay;

  @override
  int get hashCode => Object.hash(
        dest,
        amount,
        delay,
      );
}
