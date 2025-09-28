// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i6;

import '../../quantus_runtime/runtime_call.dart' as _i4;
import '../../sp_core/crypto/account_id32.dart' as _i5;
import '../../sp_runtime/multiaddress/multi_address.dart' as _i3;

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

  Map<String, dynamic> toJson();
}

class $Call {
  const $Call();

  AsRecovered asRecovered({
    required _i3.MultiAddress account,
    required _i4.RuntimeCall call,
  }) {
    return AsRecovered(
      account: account,
      call: call,
    );
  }

  SetRecovered setRecovered({
    required _i3.MultiAddress lost,
    required _i3.MultiAddress rescuer,
  }) {
    return SetRecovered(
      lost: lost,
      rescuer: rescuer,
    );
  }

  CreateRecovery createRecovery({
    required List<_i5.AccountId32> friends,
    required int threshold,
    required int delayPeriod,
  }) {
    return CreateRecovery(
      friends: friends,
      threshold: threshold,
      delayPeriod: delayPeriod,
    );
  }

  InitiateRecovery initiateRecovery({required _i3.MultiAddress account}) {
    return InitiateRecovery(account: account);
  }

  VouchRecovery vouchRecovery({
    required _i3.MultiAddress lost,
    required _i3.MultiAddress rescuer,
  }) {
    return VouchRecovery(
      lost: lost,
      rescuer: rescuer,
    );
  }

  ClaimRecovery claimRecovery({required _i3.MultiAddress account}) {
    return ClaimRecovery(account: account);
  }

  CloseRecovery closeRecovery({required _i3.MultiAddress rescuer}) {
    return CloseRecovery(rescuer: rescuer);
  }

  RemoveRecovery removeRecovery() {
    return RemoveRecovery();
  }

  CancelRecovered cancelRecovered({required _i3.MultiAddress account}) {
    return CancelRecovered(account: account);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return AsRecovered._decode(input);
      case 1:
        return SetRecovered._decode(input);
      case 2:
        return CreateRecovery._decode(input);
      case 3:
        return InitiateRecovery._decode(input);
      case 4:
        return VouchRecovery._decode(input);
      case 5:
        return ClaimRecovery._decode(input);
      case 6:
        return CloseRecovery._decode(input);
      case 7:
        return const RemoveRecovery();
      case 8:
        return CancelRecovered._decode(input);
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
      case AsRecovered:
        (value as AsRecovered).encodeTo(output);
        break;
      case SetRecovered:
        (value as SetRecovered).encodeTo(output);
        break;
      case CreateRecovery:
        (value as CreateRecovery).encodeTo(output);
        break;
      case InitiateRecovery:
        (value as InitiateRecovery).encodeTo(output);
        break;
      case VouchRecovery:
        (value as VouchRecovery).encodeTo(output);
        break;
      case ClaimRecovery:
        (value as ClaimRecovery).encodeTo(output);
        break;
      case CloseRecovery:
        (value as CloseRecovery).encodeTo(output);
        break;
      case RemoveRecovery:
        (value as RemoveRecovery).encodeTo(output);
        break;
      case CancelRecovered:
        (value as CancelRecovered).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case AsRecovered:
        return (value as AsRecovered)._sizeHint();
      case SetRecovered:
        return (value as SetRecovered)._sizeHint();
      case CreateRecovery:
        return (value as CreateRecovery)._sizeHint();
      case InitiateRecovery:
        return (value as InitiateRecovery)._sizeHint();
      case VouchRecovery:
        return (value as VouchRecovery)._sizeHint();
      case ClaimRecovery:
        return (value as ClaimRecovery)._sizeHint();
      case CloseRecovery:
        return (value as CloseRecovery)._sizeHint();
      case RemoveRecovery:
        return 1;
      case CancelRecovered:
        return (value as CancelRecovered)._sizeHint();
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Send a call through a recovered account.
///
/// The dispatch origin for this call must be _Signed_ and registered to
/// be able to make calls on behalf of the recovered account.
///
/// Parameters:
/// - `account`: The recovered account you want to make a call on-behalf-of.
/// - `call`: The call you want to make with the recovered account.
class AsRecovered extends Call {
  const AsRecovered({
    required this.account,
    required this.call,
  });

  factory AsRecovered._decode(_i1.Input input) {
    return AsRecovered(
      account: _i3.MultiAddress.codec.decode(input),
      call: _i4.RuntimeCall.codec.decode(input),
    );
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress account;

  /// Box<<T as Config>::RuntimeCall>
  final _i4.RuntimeCall call;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'as_recovered': {
          'account': account.toJson(),
          'call': call.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(account);
    size = size + _i4.RuntimeCall.codec.sizeHint(call);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      account,
      output,
    );
    _i4.RuntimeCall.codec.encodeTo(
      call,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AsRecovered && other.account == account && other.call == call;

  @override
  int get hashCode => Object.hash(
        account,
        call,
      );
}

/// Allow ROOT to bypass the recovery process and set an a rescuer account
/// for a lost account directly.
///
/// The dispatch origin for this call must be _ROOT_.
///
/// Parameters:
/// - `lost`: The "lost account" to be recovered.
/// - `rescuer`: The "rescuer account" which can call as the lost account.
class SetRecovered extends Call {
  const SetRecovered({
    required this.lost,
    required this.rescuer,
  });

  factory SetRecovered._decode(_i1.Input input) {
    return SetRecovered(
      lost: _i3.MultiAddress.codec.decode(input),
      rescuer: _i3.MultiAddress.codec.decode(input),
    );
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress lost;

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress rescuer;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'set_recovered': {
          'lost': lost.toJson(),
          'rescuer': rescuer.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(lost);
    size = size + _i3.MultiAddress.codec.sizeHint(rescuer);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      lost,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      rescuer,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is SetRecovered && other.lost == lost && other.rescuer == rescuer;

  @override
  int get hashCode => Object.hash(
        lost,
        rescuer,
      );
}

/// Create a recovery configuration for your account. This makes your account recoverable.
///
/// Payment: `ConfigDepositBase` + `FriendDepositFactor` * #_of_friends balance
/// will be reserved for storing the recovery configuration. This deposit is returned
/// in full when the user calls `remove_recovery`.
///
/// The dispatch origin for this call must be _Signed_.
///
/// Parameters:
/// - `friends`: A list of friends you trust to vouch for recovery attempts. Should be
///  ordered and contain no duplicate values.
/// - `threshold`: The number of friends that must vouch for a recovery attempt before the
///  account can be recovered. Should be less than or equal to the length of the list of
///  friends.
/// - `delay_period`: The number of blocks after a recovery attempt is initialized that
///  needs to pass before the account can be recovered.
class CreateRecovery extends Call {
  const CreateRecovery({
    required this.friends,
    required this.threshold,
    required this.delayPeriod,
  });

  factory CreateRecovery._decode(_i1.Input input) {
    return CreateRecovery(
      friends: const _i1.SequenceCodec<_i5.AccountId32>(_i5.AccountId32Codec())
          .decode(input),
      threshold: _i1.U16Codec.codec.decode(input),
      delayPeriod: _i1.U32Codec.codec.decode(input),
    );
  }

  /// Vec<T::AccountId>
  final List<_i5.AccountId32> friends;

  /// u16
  final int threshold;

  /// BlockNumberFor<T>
  final int delayPeriod;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'create_recovery': {
          'friends': friends.map((value) => value.toList()).toList(),
          'threshold': threshold,
          'delayPeriod': delayPeriod,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.SequenceCodec<_i5.AccountId32>(_i5.AccountId32Codec())
            .sizeHint(friends);
    size = size + _i1.U16Codec.codec.sizeHint(threshold);
    size = size + _i1.U32Codec.codec.sizeHint(delayPeriod);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.SequenceCodec<_i5.AccountId32>(_i5.AccountId32Codec()).encodeTo(
      friends,
      output,
    );
    _i1.U16Codec.codec.encodeTo(
      threshold,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      delayPeriod,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CreateRecovery &&
          _i6.listsEqual(
            other.friends,
            friends,
          ) &&
          other.threshold == threshold &&
          other.delayPeriod == delayPeriod;

  @override
  int get hashCode => Object.hash(
        friends,
        threshold,
        delayPeriod,
      );
}

/// Initiate the process for recovering a recoverable account.
///
/// Payment: `RecoveryDeposit` balance will be reserved for initiating the
/// recovery process. This deposit will always be repatriated to the account
/// trying to be recovered. See `close_recovery`.
///
/// The dispatch origin for this call must be _Signed_.
///
/// Parameters:
/// - `account`: The lost account that you want to recover. This account needs to be
///  recoverable (i.e. have a recovery configuration).
class InitiateRecovery extends Call {
  const InitiateRecovery({required this.account});

  factory InitiateRecovery._decode(_i1.Input input) {
    return InitiateRecovery(account: _i3.MultiAddress.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress account;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'initiate_recovery': {'account': account.toJson()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(account);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      account,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is InitiateRecovery && other.account == account;

  @override
  int get hashCode => account.hashCode;
}

/// Allow a "friend" of a recoverable account to vouch for an active recovery
/// process for that account.
///
/// The dispatch origin for this call must be _Signed_ and must be a "friend"
/// for the recoverable account.
///
/// Parameters:
/// - `lost`: The lost account that you want to recover.
/// - `rescuer`: The account trying to rescue the lost account that you want to vouch for.
///
/// The combination of these two parameters must point to an active recovery
/// process.
class VouchRecovery extends Call {
  const VouchRecovery({
    required this.lost,
    required this.rescuer,
  });

  factory VouchRecovery._decode(_i1.Input input) {
    return VouchRecovery(
      lost: _i3.MultiAddress.codec.decode(input),
      rescuer: _i3.MultiAddress.codec.decode(input),
    );
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress lost;

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress rescuer;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'vouch_recovery': {
          'lost': lost.toJson(),
          'rescuer': rescuer.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(lost);
    size = size + _i3.MultiAddress.codec.sizeHint(rescuer);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      lost,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      rescuer,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is VouchRecovery && other.lost == lost && other.rescuer == rescuer;

  @override
  int get hashCode => Object.hash(
        lost,
        rescuer,
      );
}

/// Allow a successful rescuer to claim their recovered account.
///
/// The dispatch origin for this call must be _Signed_ and must be a "rescuer"
/// who has successfully completed the account recovery process: collected
/// `threshold` or more vouches, waited `delay_period` blocks since initiation.
///
/// Parameters:
/// - `account`: The lost account that you want to claim has been successfully recovered by
///  you.
class ClaimRecovery extends Call {
  const ClaimRecovery({required this.account});

  factory ClaimRecovery._decode(_i1.Input input) {
    return ClaimRecovery(account: _i3.MultiAddress.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress account;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'claim_recovery': {'account': account.toJson()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(account);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      5,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      account,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ClaimRecovery && other.account == account;

  @override
  int get hashCode => account.hashCode;
}

/// As the controller of a recoverable account, close an active recovery
/// process for your account.
///
/// Payment: By calling this function, the recoverable account will receive
/// the recovery deposit `RecoveryDeposit` placed by the rescuer.
///
/// The dispatch origin for this call must be _Signed_ and must be a
/// recoverable account with an active recovery process for it.
///
/// Parameters:
/// - `rescuer`: The account trying to rescue this recoverable account.
class CloseRecovery extends Call {
  const CloseRecovery({required this.rescuer});

  factory CloseRecovery._decode(_i1.Input input) {
    return CloseRecovery(rescuer: _i3.MultiAddress.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress rescuer;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'close_recovery': {'rescuer': rescuer.toJson()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(rescuer);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      6,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      rescuer,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CloseRecovery && other.rescuer == rescuer;

  @override
  int get hashCode => rescuer.hashCode;
}

/// Remove the recovery process for your account. Recovered accounts are still accessible.
///
/// NOTE: The user must make sure to call `close_recovery` on all active
/// recovery attempts before calling this function else it will fail.
///
/// Payment: By calling this function the recoverable account will unreserve
/// their recovery configuration deposit.
/// (`ConfigDepositBase` + `FriendDepositFactor` * #_of_friends)
///
/// The dispatch origin for this call must be _Signed_ and must be a
/// recoverable account (i.e. has a recovery configuration).
class RemoveRecovery extends Call {
  const RemoveRecovery();

  @override
  Map<String, dynamic> toJson() => {'remove_recovery': null};

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      7,
      output,
    );
  }

  @override
  bool operator ==(Object other) => other is RemoveRecovery;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Cancel the ability to use `as_recovered` for `account`.
///
/// The dispatch origin for this call must be _Signed_ and registered to
/// be able to make calls on behalf of the recovered account.
///
/// Parameters:
/// - `account`: The recovered account you are able to call on-behalf-of.
class CancelRecovered extends Call {
  const CancelRecovered({required this.account});

  factory CancelRecovered._decode(_i1.Input input) {
    return CancelRecovered(account: _i3.MultiAddress.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress account;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'cancel_recovered': {'account': account.toJson()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(account);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      8,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      account,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CancelRecovered && other.account == account;

  @override
  int get hashCode => account.hashCode;
}
