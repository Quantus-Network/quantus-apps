// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i7;

import '../../primitive_types/h256.dart' as _i5;
import '../../qp_scheduler/block_number_or_timestamp.dart' as _i3;
import '../../sp_core/crypto/account_id32.dart' as _i4;
import '../../sp_runtime/multiaddress/multi_address.dart' as _i6;

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

  SetHighSecurity setHighSecurity({required _i3.BlockNumberOrTimestamp delay, required _i4.AccountId32 guardian}) {
    return SetHighSecurity(delay: delay, guardian: guardian);
  }

  Cancel cancel({required _i5.H256 txId}) {
    return Cancel(txId: txId);
  }

  ExecuteTransfer executeTransfer({required _i5.H256 txId}) {
    return ExecuteTransfer(txId: txId);
  }

  ScheduleTransfer scheduleTransfer({required _i6.MultiAddress dest, required BigInt amount}) {
    return ScheduleTransfer(dest: dest, amount: amount);
  }

  ScheduleTransferWithDelay scheduleTransferWithDelay({
    required _i6.MultiAddress dest,
    required BigInt amount,
    required _i3.BlockNumberOrTimestamp delay,
  }) {
    return ScheduleTransferWithDelay(dest: dest, amount: amount, delay: delay);
  }

  ScheduleAssetTransfer scheduleAssetTransfer({
    required int assetId,
    required _i6.MultiAddress dest,
    required BigInt amount,
  }) {
    return ScheduleAssetTransfer(assetId: assetId, dest: dest, amount: amount);
  }

  ScheduleAssetTransferWithDelay scheduleAssetTransferWithDelay({
    required int assetId,
    required _i6.MultiAddress dest,
    required BigInt amount,
    required _i3.BlockNumberOrTimestamp delay,
  }) {
    return ScheduleAssetTransferWithDelay(assetId: assetId, dest: dest, amount: amount, delay: delay);
  }

  RecoverFunds recoverFunds({required _i4.AccountId32 account}) {
    return RecoverFunds(account: account);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return SetHighSecurity._decode(input);
      case 1:
        return Cancel._decode(input);
      case 2:
        return ExecuteTransfer._decode(input);
      case 3:
        return ScheduleTransfer._decode(input);
      case 4:
        return ScheduleTransferWithDelay._decode(input);
      case 5:
        return ScheduleAssetTransfer._decode(input);
      case 6:
        return ScheduleAssetTransferWithDelay._decode(input);
      case 7:
        return RecoverFunds._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case SetHighSecurity:
        (value as SetHighSecurity).encodeTo(output);
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
      case ScheduleAssetTransfer:
        (value as ScheduleAssetTransfer).encodeTo(output);
        break;
      case ScheduleAssetTransferWithDelay:
        (value as ScheduleAssetTransferWithDelay).encodeTo(output);
        break;
      case RecoverFunds:
        (value as RecoverFunds).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case SetHighSecurity:
        return (value as SetHighSecurity)._sizeHint();
      case Cancel:
        return (value as Cancel)._sizeHint();
      case ExecuteTransfer:
        return (value as ExecuteTransfer)._sizeHint();
      case ScheduleTransfer:
        return (value as ScheduleTransfer)._sizeHint();
      case ScheduleTransferWithDelay:
        return (value as ScheduleTransferWithDelay)._sizeHint();
      case ScheduleAssetTransfer:
        return (value as ScheduleAssetTransfer)._sizeHint();
      case ScheduleAssetTransferWithDelay:
        return (value as ScheduleAssetTransferWithDelay)._sizeHint();
      case RecoverFunds:
        return (value as RecoverFunds)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Enable high-security for the calling account with a specified
/// reversibility delay.
///
/// Once an account is set as high security it can only make reversible
/// transfers. It is not allowed any other calls.
///
/// # Warning: Permanent and Irreversible
///
/// **Enabling high security mode is a one-way operation that cannot be undone.**
///
/// Once this function is called successfully, the account is permanently restricted
/// to only the following operations:
/// - [`schedule_transfer`](Self::schedule_transfer) - Schedule delayed native token
///  transfers
/// - [`schedule_asset_transfer`](Self::schedule_asset_transfer) - Schedule delayed asset
///  transfers
/// - [`cancel`](Self::cancel) - Cancel pending transfers
/// - [`recover_funds`](Self::recover_funds) - Guardian-initiated emergency fund recovery
///
/// There is no mechanism to disable high security mode or restore normal account
/// functionality. This design is intentional to provide maximum security guarantees:
/// an attacker who gains access to the account cannot simply disable the protections.
///
/// Users who no longer wish to use high-security features can simply transfer their
/// funds to a different account using [`schedule_transfer`](Self::schedule_transfer)
/// or [`schedule_asset_transfer`](Self::schedule_asset_transfer).
///
/// # Parameters
///
/// - `delay`: The reversibility time for any transfer made by the high-security account.
/// - `guardian`: The guardian account that can cancel pending transfers and recover funds
///  from this high-security account.
class SetHighSecurity extends Call {
  const SetHighSecurity({required this.delay, required this.guardian});

  factory SetHighSecurity._decode(_i1.Input input) {
    return SetHighSecurity(
      delay: _i3.BlockNumberOrTimestamp.codec.decode(input),
      guardian: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// BlockNumberOrTimestampOf<T>
  final _i3.BlockNumberOrTimestamp delay;

  /// T::AccountId
  final _i4.AccountId32 guardian;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'set_high_security': {'delay': delay.toJson(), 'guardian': guardian.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.BlockNumberOrTimestamp.codec.sizeHint(delay);
    size = size + const _i4.AccountId32Codec().sizeHint(guardian);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i3.BlockNumberOrTimestamp.codec.encodeTo(delay, output);
    const _i1.U8ArrayCodec(32).encodeTo(guardian, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetHighSecurity && other.delay == delay && _i7.listsEqual(other.guardian, guardian);

  @override
  int get hashCode => Object.hash(delay, guardian);
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
  final _i5.H256 txId;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'cancel': {'txId': txId.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i5.H256Codec().sizeHint(txId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    const _i1.U8ArrayCodec(32).encodeTo(txId, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Cancel && _i7.listsEqual(other.txId, txId);

  @override
  int get hashCode => txId.hashCode;
}

/// Executes a previously scheduled transfer after the delay period has elapsed.
///
/// This extrinsic is called automatically by the Scheduler pallet when the
/// delay period expires. It must be signed by this pallet's account (not a user).
/// The pallet account is set as the origin when scheduling via
/// [`do_schedule_transfer_inner`](Self::do_schedule_transfer_inner).
///
/// # Parameters
///
/// - `tx_id`: The unique identifier of the pending transfer to execute.
///
/// # Errors
///
/// - [`InvalidSchedulerOrigin`](Error::InvalidSchedulerOrigin): Called by an account other
///  than this pallet's account.
/// - [`PendingTxNotFound`](Error::PendingTxNotFound): No pending transfer with this ID.
class ExecuteTransfer extends Call {
  const ExecuteTransfer({required this.txId});

  factory ExecuteTransfer._decode(_i1.Input input) {
    return ExecuteTransfer(txId: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::Hash
  final _i5.H256 txId;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'execute_transfer': {'txId': txId.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i5.H256Codec().sizeHint(txId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    const _i1.U8ArrayCodec(32).encodeTo(txId, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ExecuteTransfer && _i7.listsEqual(other.txId, txId);

  @override
  int get hashCode => txId.hashCode;
}

/// Schedule a transaction for delayed execution.
class ScheduleTransfer extends Call {
  const ScheduleTransfer({required this.dest, required this.amount});

  factory ScheduleTransfer._decode(_i1.Input input) {
    return ScheduleTransfer(dest: _i6.MultiAddress.codec.decode(input), amount: _i1.U128Codec.codec.decode(input));
  }

  /// <<T as frame_system::Config>::Lookup as StaticLookup>::Source
  final _i6.MultiAddress dest;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'schedule_transfer': {'dest': dest.toJson(), 'amount': amount},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i6.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    _i6.MultiAddress.codec.encodeTo(dest, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ScheduleTransfer && other.dest == dest && other.amount == amount;

  @override
  int get hashCode => Object.hash(dest, amount);
}

/// Schedule a transaction for delayed execution with a custom, one-time delay.
///
/// This can only be used by accounts that have *not* set up a persistent
/// reversibility configuration with `set_high_security`.
///
/// - `delay`: The time (in blocks or milliseconds) before the transaction executes.
class ScheduleTransferWithDelay extends Call {
  const ScheduleTransferWithDelay({required this.dest, required this.amount, required this.delay});

  factory ScheduleTransferWithDelay._decode(_i1.Input input) {
    return ScheduleTransferWithDelay(
      dest: _i6.MultiAddress.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      delay: _i3.BlockNumberOrTimestamp.codec.decode(input),
    );
  }

  /// <<T as frame_system::Config>::Lookup as StaticLookup>::Source
  final _i6.MultiAddress dest;

  /// BalanceOf<T>
  final BigInt amount;

  /// BlockNumberOrTimestampOf<T>
  final _i3.BlockNumberOrTimestamp delay;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'schedule_transfer_with_delay': {'dest': dest.toJson(), 'amount': amount, 'delay': delay.toJson()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i6.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + _i3.BlockNumberOrTimestamp.codec.sizeHint(delay);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(4, output);
    _i6.MultiAddress.codec.encodeTo(dest, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
    _i3.BlockNumberOrTimestamp.codec.encodeTo(delay, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleTransferWithDelay && other.dest == dest && other.amount == amount && other.delay == delay;

  @override
  int get hashCode => Object.hash(dest, amount, delay);
}

/// Schedule an asset transfer (pallet-assets) for delayed execution using the configured
/// delay.
class ScheduleAssetTransfer extends Call {
  const ScheduleAssetTransfer({required this.assetId, required this.dest, required this.amount});

  factory ScheduleAssetTransfer._decode(_i1.Input input) {
    return ScheduleAssetTransfer(
      assetId: _i1.U32Codec.codec.decode(input),
      dest: _i6.MultiAddress.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// AssetIdOf<T>
  final int assetId;

  /// <<T as frame_system::Config>::Lookup as StaticLookup>::Source
  final _i6.MultiAddress dest;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'schedule_asset_transfer': {'assetId': assetId, 'dest': dest.toJson(), 'amount': amount},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(assetId);
    size = size + _i6.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(5, output);
    _i1.U32Codec.codec.encodeTo(assetId, output);
    _i6.MultiAddress.codec.encodeTo(dest, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleAssetTransfer && other.assetId == assetId && other.dest == dest && other.amount == amount;

  @override
  int get hashCode => Object.hash(assetId, dest, amount);
}

/// Schedule an asset transfer (pallet-assets) with a custom one-time delay.
class ScheduleAssetTransferWithDelay extends Call {
  const ScheduleAssetTransferWithDelay({
    required this.assetId,
    required this.dest,
    required this.amount,
    required this.delay,
  });

  factory ScheduleAssetTransferWithDelay._decode(_i1.Input input) {
    return ScheduleAssetTransferWithDelay(
      assetId: _i1.U32Codec.codec.decode(input),
      dest: _i6.MultiAddress.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      delay: _i3.BlockNumberOrTimestamp.codec.decode(input),
    );
  }

  /// AssetIdOf<T>
  final int assetId;

  /// <<T as frame_system::Config>::Lookup as StaticLookup>::Source
  final _i6.MultiAddress dest;

  /// BalanceOf<T>
  final BigInt amount;

  /// BlockNumberOrTimestampOf<T>
  final _i3.BlockNumberOrTimestamp delay;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'schedule_asset_transfer_with_delay': {
      'assetId': assetId,
      'dest': dest.toJson(),
      'amount': amount,
      'delay': delay.toJson(),
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(assetId);
    size = size + _i6.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + _i3.BlockNumberOrTimestamp.codec.sizeHint(delay);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(6, output);
    _i1.U32Codec.codec.encodeTo(assetId, output);
    _i6.MultiAddress.codec.encodeTo(dest, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
    _i3.BlockNumberOrTimestamp.codec.encodeTo(delay, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleAssetTransferWithDelay &&
          other.assetId == assetId &&
          other.dest == dest &&
          other.amount == amount &&
          other.delay == delay;

  @override
  int get hashCode => Object.hash(assetId, dest, amount, delay);
}

/// Allows the guardian to recover all funds from a high-security account
/// by transferring the entire balance to themselves.
///
/// This is an emergency function for when the high-security account may be compromised.
/// It cancels all pending transfers first (applying volume fees), then transfers
/// the remaining free balance to the guardian.
///
/// If releasing held funds fails for any transfer, that transfer is skipped (metadata
/// preserved for manual retry via `cancel`) and a `TransferRecoveryFailed` event is
/// emitted. Other transfers continue to be processed.
class RecoverFunds extends Call {
  const RecoverFunds({required this.account});

  factory RecoverFunds._decode(_i1.Input input) {
    return RecoverFunds(account: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i4.AccountId32 account;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'recover_funds': {'account': account.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i4.AccountId32Codec().sizeHint(account);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(7, output);
    const _i1.U8ArrayCodec(32).encodeTo(account, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RecoverFunds && _i7.listsEqual(other.account, account);

  @override
  int get hashCode => account.hashCode;
}
