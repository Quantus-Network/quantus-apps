// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i9;

import '../../frame_support/dispatch/post_dispatch_info.dart' as _i7;
import '../../primitive_types/h256.dart' as _i5;
import '../../qp_scheduler/block_number_or_timestamp.dart' as _i4;
import '../../qp_scheduler/dispatch_time.dart' as _i6;
import '../../sp_core/crypto/account_id32.dart' as _i3;
import '../../sp_runtime/dispatch_error_with_post_info.dart' as _i8;

/// The `Event` enum of this pallet
abstract class Event {
  const Event();

  factory Event.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $EventCodec codec = $EventCodec();

  static const $Event values = $Event();

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

class $Event {
  const $Event();

  HighSecuritySet highSecuritySet({
    required _i3.AccountId32 who,
    required _i3.AccountId32 interceptor,
    required _i3.AccountId32 recoverer,
    required _i4.BlockNumberOrTimestamp delay,
  }) {
    return HighSecuritySet(
      who: who,
      interceptor: interceptor,
      recoverer: recoverer,
      delay: delay,
    );
  }

  TransactionScheduled transactionScheduled({
    required _i3.AccountId32 from,
    required _i3.AccountId32 to,
    required _i3.AccountId32 interceptor,
    required BigInt amount,
    required _i5.H256 txId,
    required _i6.DispatchTime executeAt,
  }) {
    return TransactionScheduled(
      from: from,
      to: to,
      interceptor: interceptor,
      amount: amount,
      txId: txId,
      executeAt: executeAt,
    );
  }

  TransactionCancelled transactionCancelled({
    required _i3.AccountId32 who,
    required _i5.H256 txId,
  }) {
    return TransactionCancelled(
      who: who,
      txId: txId,
    );
  }

  TransactionExecuted transactionExecuted({
    required _i5.H256 txId,
    required _i1.Result<_i7.PostDispatchInfo, _i8.DispatchErrorWithPostInfo>
        result,
  }) {
    return TransactionExecuted(
      txId: txId,
      result: result,
    );
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return HighSecuritySet._decode(input);
      case 1:
        return TransactionScheduled._decode(input);
      case 2:
        return TransactionCancelled._decode(input);
      case 3:
        return TransactionExecuted._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Event value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case HighSecuritySet:
        (value as HighSecuritySet).encodeTo(output);
        break;
      case TransactionScheduled:
        (value as TransactionScheduled).encodeTo(output);
        break;
      case TransactionCancelled:
        (value as TransactionCancelled).encodeTo(output);
        break;
      case TransactionExecuted:
        (value as TransactionExecuted).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case HighSecuritySet:
        return (value as HighSecuritySet)._sizeHint();
      case TransactionScheduled:
        return (value as TransactionScheduled)._sizeHint();
      case TransactionCancelled:
        return (value as TransactionCancelled)._sizeHint();
      case TransactionExecuted:
        return (value as TransactionExecuted)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A user has enabled their high-security settings.
/// [who, interceptor, recoverer, delay]
class HighSecuritySet extends Event {
  const HighSecuritySet({
    required this.who,
    required this.interceptor,
    required this.recoverer,
    required this.delay,
  });

  factory HighSecuritySet._decode(_i1.Input input) {
    return HighSecuritySet(
      who: const _i1.U8ArrayCodec(32).decode(input),
      interceptor: const _i1.U8ArrayCodec(32).decode(input),
      recoverer: const _i1.U8ArrayCodec(32).decode(input),
      delay: _i4.BlockNumberOrTimestamp.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// T::AccountId
  final _i3.AccountId32 interceptor;

  /// T::AccountId
  final _i3.AccountId32 recoverer;

  /// BlockNumberOrTimestampOf<T>
  final _i4.BlockNumberOrTimestamp delay;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'HighSecuritySet': {
          'who': who.toList(),
          'interceptor': interceptor.toList(),
          'recoverer': recoverer.toList(),
          'delay': delay.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + const _i3.AccountId32Codec().sizeHint(interceptor);
    size = size + const _i3.AccountId32Codec().sizeHint(recoverer);
    size = size + _i4.BlockNumberOrTimestamp.codec.sizeHint(delay);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      interceptor,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      recoverer,
      output,
    );
    _i4.BlockNumberOrTimestamp.codec.encodeTo(
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
      other is HighSecuritySet &&
          _i9.listsEqual(
            other.who,
            who,
          ) &&
          _i9.listsEqual(
            other.interceptor,
            interceptor,
          ) &&
          _i9.listsEqual(
            other.recoverer,
            recoverer,
          ) &&
          other.delay == delay;

  @override
  int get hashCode => Object.hash(
        who,
        interceptor,
        recoverer,
        delay,
      );
}

/// A transaction has been intercepted and scheduled for delayed execution.
/// [from, to, interceptor, amount, tx_id, execute_at_moment]
class TransactionScheduled extends Event {
  const TransactionScheduled({
    required this.from,
    required this.to,
    required this.interceptor,
    required this.amount,
    required this.txId,
    required this.executeAt,
  });

  factory TransactionScheduled._decode(_i1.Input input) {
    return TransactionScheduled(
      from: const _i1.U8ArrayCodec(32).decode(input),
      to: const _i1.U8ArrayCodec(32).decode(input),
      interceptor: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      txId: const _i1.U8ArrayCodec(32).decode(input),
      executeAt: _i6.DispatchTime.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 from;

  /// T::AccountId
  final _i3.AccountId32 to;

  /// T::AccountId
  final _i3.AccountId32 interceptor;

  /// T::Balance
  final BigInt amount;

  /// T::Hash
  final _i5.H256 txId;

  /// DispatchTime<BlockNumberFor<T>, T::Moment>
  final _i6.DispatchTime executeAt;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'TransactionScheduled': {
          'from': from.toList(),
          'to': to.toList(),
          'interceptor': interceptor.toList(),
          'amount': amount,
          'txId': txId.toList(),
          'executeAt': executeAt.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(from);
    size = size + const _i3.AccountId32Codec().sizeHint(to);
    size = size + const _i3.AccountId32Codec().sizeHint(interceptor);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + const _i5.H256Codec().sizeHint(txId);
    size = size + _i6.DispatchTime.codec.sizeHint(executeAt);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      from,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      to,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      interceptor,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      txId,
      output,
    );
    _i6.DispatchTime.codec.encodeTo(
      executeAt,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is TransactionScheduled &&
          _i9.listsEqual(
            other.from,
            from,
          ) &&
          _i9.listsEqual(
            other.to,
            to,
          ) &&
          _i9.listsEqual(
            other.interceptor,
            interceptor,
          ) &&
          other.amount == amount &&
          _i9.listsEqual(
            other.txId,
            txId,
          ) &&
          other.executeAt == executeAt;

  @override
  int get hashCode => Object.hash(
        from,
        to,
        interceptor,
        amount,
        txId,
        executeAt,
      );
}

/// A scheduled transaction has been successfully cancelled by the owner.
/// [who, tx_id]
class TransactionCancelled extends Event {
  const TransactionCancelled({
    required this.who,
    required this.txId,
  });

  factory TransactionCancelled._decode(_i1.Input input) {
    return TransactionCancelled(
      who: const _i1.U8ArrayCodec(32).decode(input),
      txId: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// T::Hash
  final _i5.H256 txId;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'TransactionCancelled': {
          'who': who.toList(),
          'txId': txId.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + const _i5.H256Codec().sizeHint(txId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
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
      other is TransactionCancelled &&
          _i9.listsEqual(
            other.who,
            who,
          ) &&
          _i9.listsEqual(
            other.txId,
            txId,
          );

  @override
  int get hashCode => Object.hash(
        who,
        txId,
      );
}

/// A scheduled transaction was executed by the scheduler.
/// [tx_id, dispatch_result]
class TransactionExecuted extends Event {
  const TransactionExecuted({
    required this.txId,
    required this.result,
  });

  factory TransactionExecuted._decode(_i1.Input input) {
    return TransactionExecuted(
      txId: const _i1.U8ArrayCodec(32).decode(input),
      result: const _i1
          .ResultCodec<_i7.PostDispatchInfo, _i8.DispatchErrorWithPostInfo>(
        _i7.PostDispatchInfo.codec,
        _i8.DispatchErrorWithPostInfo.codec,
      ).decode(input),
    );
  }

  /// T::Hash
  final _i5.H256 txId;

  /// DispatchResultWithPostInfo
  final _i1.Result<_i7.PostDispatchInfo, _i8.DispatchErrorWithPostInfo> result;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'TransactionExecuted': {
          'txId': txId.toList(),
          'result': result.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i5.H256Codec().sizeHint(txId);
    size = size +
        const _i1
            .ResultCodec<_i7.PostDispatchInfo, _i8.DispatchErrorWithPostInfo>(
          _i7.PostDispatchInfo.codec,
          _i8.DispatchErrorWithPostInfo.codec,
        ).sizeHint(result);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      txId,
      output,
    );
    const _i1.ResultCodec<_i7.PostDispatchInfo, _i8.DispatchErrorWithPostInfo>(
      _i7.PostDispatchInfo.codec,
      _i8.DispatchErrorWithPostInfo.codec,
    ).encodeTo(
      result,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is TransactionExecuted &&
          _i9.listsEqual(
            other.txId,
            txId,
          ) &&
          other.result == result;

  @override
  int get hashCode => Object.hash(
        txId,
        result,
      );
}
