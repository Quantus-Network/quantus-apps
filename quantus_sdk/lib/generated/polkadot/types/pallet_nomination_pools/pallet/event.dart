// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i10;

import '../../sp_arithmetic/per_things/perbill.dart' as _i6;
import '../../sp_core/crypto/account_id32.dart' as _i3;
import '../../tuples.dart' as _i5;
import '../claim_permission.dart' as _i9;
import '../commission_change_rate.dart' as _i7;
import '../commission_claim_permission.dart' as _i8;
import '../pool_state.dart' as _i4;

/// Events of this pallet.
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

  Created created({
    required _i3.AccountId32 depositor,
    required int poolId,
  }) {
    return Created(
      depositor: depositor,
      poolId: poolId,
    );
  }

  Bonded bonded({
    required _i3.AccountId32 member,
    required int poolId,
    required BigInt bonded,
    required bool joined,
  }) {
    return Bonded(
      member: member,
      poolId: poolId,
      bonded: bonded,
      joined: joined,
    );
  }

  PaidOut paidOut({
    required _i3.AccountId32 member,
    required int poolId,
    required BigInt payout,
  }) {
    return PaidOut(
      member: member,
      poolId: poolId,
      payout: payout,
    );
  }

  Unbonded unbonded({
    required _i3.AccountId32 member,
    required int poolId,
    required BigInt balance,
    required BigInt points,
    required int era,
  }) {
    return Unbonded(
      member: member,
      poolId: poolId,
      balance: balance,
      points: points,
      era: era,
    );
  }

  Withdrawn withdrawn({
    required _i3.AccountId32 member,
    required int poolId,
    required BigInt balance,
    required BigInt points,
  }) {
    return Withdrawn(
      member: member,
      poolId: poolId,
      balance: balance,
      points: points,
    );
  }

  Destroyed destroyed({required int poolId}) {
    return Destroyed(poolId: poolId);
  }

  StateChanged stateChanged({
    required int poolId,
    required _i4.PoolState newState,
  }) {
    return StateChanged(
      poolId: poolId,
      newState: newState,
    );
  }

  MemberRemoved memberRemoved({
    required int poolId,
    required _i3.AccountId32 member,
    required BigInt releasedBalance,
  }) {
    return MemberRemoved(
      poolId: poolId,
      member: member,
      releasedBalance: releasedBalance,
    );
  }

  RolesUpdated rolesUpdated({
    _i3.AccountId32? root,
    _i3.AccountId32? bouncer,
    _i3.AccountId32? nominator,
  }) {
    return RolesUpdated(
      root: root,
      bouncer: bouncer,
      nominator: nominator,
    );
  }

  PoolSlashed poolSlashed({
    required int poolId,
    required BigInt balance,
  }) {
    return PoolSlashed(
      poolId: poolId,
      balance: balance,
    );
  }

  UnbondingPoolSlashed unbondingPoolSlashed({
    required int poolId,
    required int era,
    required BigInt balance,
  }) {
    return UnbondingPoolSlashed(
      poolId: poolId,
      era: era,
      balance: balance,
    );
  }

  PoolCommissionUpdated poolCommissionUpdated({
    required int poolId,
    _i5.Tuple2<_i6.Perbill, _i3.AccountId32>? current,
  }) {
    return PoolCommissionUpdated(
      poolId: poolId,
      current: current,
    );
  }

  PoolMaxCommissionUpdated poolMaxCommissionUpdated({
    required int poolId,
    required _i6.Perbill maxCommission,
  }) {
    return PoolMaxCommissionUpdated(
      poolId: poolId,
      maxCommission: maxCommission,
    );
  }

  PoolCommissionChangeRateUpdated poolCommissionChangeRateUpdated({
    required int poolId,
    required _i7.CommissionChangeRate changeRate,
  }) {
    return PoolCommissionChangeRateUpdated(
      poolId: poolId,
      changeRate: changeRate,
    );
  }

  PoolCommissionClaimPermissionUpdated poolCommissionClaimPermissionUpdated({
    required int poolId,
    _i8.CommissionClaimPermission? permission,
  }) {
    return PoolCommissionClaimPermissionUpdated(
      poolId: poolId,
      permission: permission,
    );
  }

  PoolCommissionClaimed poolCommissionClaimed({
    required int poolId,
    required BigInt commission,
  }) {
    return PoolCommissionClaimed(
      poolId: poolId,
      commission: commission,
    );
  }

  MinBalanceDeficitAdjusted minBalanceDeficitAdjusted({
    required int poolId,
    required BigInt amount,
  }) {
    return MinBalanceDeficitAdjusted(
      poolId: poolId,
      amount: amount,
    );
  }

  MinBalanceExcessAdjusted minBalanceExcessAdjusted({
    required int poolId,
    required BigInt amount,
  }) {
    return MinBalanceExcessAdjusted(
      poolId: poolId,
      amount: amount,
    );
  }

  MemberClaimPermissionUpdated memberClaimPermissionUpdated({
    required _i3.AccountId32 member,
    required _i9.ClaimPermission permission,
  }) {
    return MemberClaimPermissionUpdated(
      member: member,
      permission: permission,
    );
  }

  MetadataUpdated metadataUpdated({
    required int poolId,
    required _i3.AccountId32 caller,
  }) {
    return MetadataUpdated(
      poolId: poolId,
      caller: caller,
    );
  }

  PoolNominationMade poolNominationMade({
    required int poolId,
    required _i3.AccountId32 caller,
  }) {
    return PoolNominationMade(
      poolId: poolId,
      caller: caller,
    );
  }

  PoolNominatorChilled poolNominatorChilled({
    required int poolId,
    required _i3.AccountId32 caller,
  }) {
    return PoolNominatorChilled(
      poolId: poolId,
      caller: caller,
    );
  }

  GlobalParamsUpdated globalParamsUpdated({
    required BigInt minJoinBond,
    required BigInt minCreateBond,
    int? maxPools,
    int? maxMembers,
    int? maxMembersPerPool,
    _i6.Perbill? globalMaxCommission,
  }) {
    return GlobalParamsUpdated(
      minJoinBond: minJoinBond,
      minCreateBond: minCreateBond,
      maxPools: maxPools,
      maxMembers: maxMembers,
      maxMembersPerPool: maxMembersPerPool,
      globalMaxCommission: globalMaxCommission,
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
        return Created._decode(input);
      case 1:
        return Bonded._decode(input);
      case 2:
        return PaidOut._decode(input);
      case 3:
        return Unbonded._decode(input);
      case 4:
        return Withdrawn._decode(input);
      case 5:
        return Destroyed._decode(input);
      case 6:
        return StateChanged._decode(input);
      case 7:
        return MemberRemoved._decode(input);
      case 8:
        return RolesUpdated._decode(input);
      case 9:
        return PoolSlashed._decode(input);
      case 10:
        return UnbondingPoolSlashed._decode(input);
      case 11:
        return PoolCommissionUpdated._decode(input);
      case 12:
        return PoolMaxCommissionUpdated._decode(input);
      case 13:
        return PoolCommissionChangeRateUpdated._decode(input);
      case 14:
        return PoolCommissionClaimPermissionUpdated._decode(input);
      case 15:
        return PoolCommissionClaimed._decode(input);
      case 16:
        return MinBalanceDeficitAdjusted._decode(input);
      case 17:
        return MinBalanceExcessAdjusted._decode(input);
      case 18:
        return MemberClaimPermissionUpdated._decode(input);
      case 19:
        return MetadataUpdated._decode(input);
      case 20:
        return PoolNominationMade._decode(input);
      case 21:
        return PoolNominatorChilled._decode(input);
      case 22:
        return GlobalParamsUpdated._decode(input);
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
      case Created:
        (value as Created).encodeTo(output);
        break;
      case Bonded:
        (value as Bonded).encodeTo(output);
        break;
      case PaidOut:
        (value as PaidOut).encodeTo(output);
        break;
      case Unbonded:
        (value as Unbonded).encodeTo(output);
        break;
      case Withdrawn:
        (value as Withdrawn).encodeTo(output);
        break;
      case Destroyed:
        (value as Destroyed).encodeTo(output);
        break;
      case StateChanged:
        (value as StateChanged).encodeTo(output);
        break;
      case MemberRemoved:
        (value as MemberRemoved).encodeTo(output);
        break;
      case RolesUpdated:
        (value as RolesUpdated).encodeTo(output);
        break;
      case PoolSlashed:
        (value as PoolSlashed).encodeTo(output);
        break;
      case UnbondingPoolSlashed:
        (value as UnbondingPoolSlashed).encodeTo(output);
        break;
      case PoolCommissionUpdated:
        (value as PoolCommissionUpdated).encodeTo(output);
        break;
      case PoolMaxCommissionUpdated:
        (value as PoolMaxCommissionUpdated).encodeTo(output);
        break;
      case PoolCommissionChangeRateUpdated:
        (value as PoolCommissionChangeRateUpdated).encodeTo(output);
        break;
      case PoolCommissionClaimPermissionUpdated:
        (value as PoolCommissionClaimPermissionUpdated).encodeTo(output);
        break;
      case PoolCommissionClaimed:
        (value as PoolCommissionClaimed).encodeTo(output);
        break;
      case MinBalanceDeficitAdjusted:
        (value as MinBalanceDeficitAdjusted).encodeTo(output);
        break;
      case MinBalanceExcessAdjusted:
        (value as MinBalanceExcessAdjusted).encodeTo(output);
        break;
      case MemberClaimPermissionUpdated:
        (value as MemberClaimPermissionUpdated).encodeTo(output);
        break;
      case MetadataUpdated:
        (value as MetadataUpdated).encodeTo(output);
        break;
      case PoolNominationMade:
        (value as PoolNominationMade).encodeTo(output);
        break;
      case PoolNominatorChilled:
        (value as PoolNominatorChilled).encodeTo(output);
        break;
      case GlobalParamsUpdated:
        (value as GlobalParamsUpdated).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case Created:
        return (value as Created)._sizeHint();
      case Bonded:
        return (value as Bonded)._sizeHint();
      case PaidOut:
        return (value as PaidOut)._sizeHint();
      case Unbonded:
        return (value as Unbonded)._sizeHint();
      case Withdrawn:
        return (value as Withdrawn)._sizeHint();
      case Destroyed:
        return (value as Destroyed)._sizeHint();
      case StateChanged:
        return (value as StateChanged)._sizeHint();
      case MemberRemoved:
        return (value as MemberRemoved)._sizeHint();
      case RolesUpdated:
        return (value as RolesUpdated)._sizeHint();
      case PoolSlashed:
        return (value as PoolSlashed)._sizeHint();
      case UnbondingPoolSlashed:
        return (value as UnbondingPoolSlashed)._sizeHint();
      case PoolCommissionUpdated:
        return (value as PoolCommissionUpdated)._sizeHint();
      case PoolMaxCommissionUpdated:
        return (value as PoolMaxCommissionUpdated)._sizeHint();
      case PoolCommissionChangeRateUpdated:
        return (value as PoolCommissionChangeRateUpdated)._sizeHint();
      case PoolCommissionClaimPermissionUpdated:
        return (value as PoolCommissionClaimPermissionUpdated)._sizeHint();
      case PoolCommissionClaimed:
        return (value as PoolCommissionClaimed)._sizeHint();
      case MinBalanceDeficitAdjusted:
        return (value as MinBalanceDeficitAdjusted)._sizeHint();
      case MinBalanceExcessAdjusted:
        return (value as MinBalanceExcessAdjusted)._sizeHint();
      case MemberClaimPermissionUpdated:
        return (value as MemberClaimPermissionUpdated)._sizeHint();
      case MetadataUpdated:
        return (value as MetadataUpdated)._sizeHint();
      case PoolNominationMade:
        return (value as PoolNominationMade)._sizeHint();
      case PoolNominatorChilled:
        return (value as PoolNominatorChilled)._sizeHint();
      case GlobalParamsUpdated:
        return (value as GlobalParamsUpdated)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A pool has been created.
class Created extends Event {
  const Created({
    required this.depositor,
    required this.poolId,
  });

  factory Created._decode(_i1.Input input) {
    return Created(
      depositor: const _i1.U8ArrayCodec(32).decode(input),
      poolId: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 depositor;

  /// PoolId
  final int poolId;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Created': {
          'depositor': depositor.toList(),
          'poolId': poolId,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(depositor);
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      depositor,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Created &&
          _i10.listsEqual(
            other.depositor,
            depositor,
          ) &&
          other.poolId == poolId;

  @override
  int get hashCode => Object.hash(
        depositor,
        poolId,
      );
}

/// A member has became bonded in a pool.
class Bonded extends Event {
  const Bonded({
    required this.member,
    required this.poolId,
    required this.bonded,
    required this.joined,
  });

  factory Bonded._decode(_i1.Input input) {
    return Bonded(
      member: const _i1.U8ArrayCodec(32).decode(input),
      poolId: _i1.U32Codec.codec.decode(input),
      bonded: _i1.U128Codec.codec.decode(input),
      joined: _i1.BoolCodec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 member;

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt bonded;

  /// bool
  final bool joined;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Bonded': {
          'member': member.toList(),
          'poolId': poolId,
          'bonded': bonded,
          'joined': joined,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(member);
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(bonded);
    size = size + _i1.BoolCodec.codec.sizeHint(joined);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      member,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      bonded,
      output,
    );
    _i1.BoolCodec.codec.encodeTo(
      joined,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Bonded &&
          _i10.listsEqual(
            other.member,
            member,
          ) &&
          other.poolId == poolId &&
          other.bonded == bonded &&
          other.joined == joined;

  @override
  int get hashCode => Object.hash(
        member,
        poolId,
        bonded,
        joined,
      );
}

/// A payout has been made to a member.
class PaidOut extends Event {
  const PaidOut({
    required this.member,
    required this.poolId,
    required this.payout,
  });

  factory PaidOut._decode(_i1.Input input) {
    return PaidOut(
      member: const _i1.U8ArrayCodec(32).decode(input),
      poolId: _i1.U32Codec.codec.decode(input),
      payout: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 member;

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt payout;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PaidOut': {
          'member': member.toList(),
          'poolId': poolId,
          'payout': payout,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(member);
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(payout);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      member,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      payout,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PaidOut &&
          _i10.listsEqual(
            other.member,
            member,
          ) &&
          other.poolId == poolId &&
          other.payout == payout;

  @override
  int get hashCode => Object.hash(
        member,
        poolId,
        payout,
      );
}

/// A member has unbonded from their pool.
///
/// - `balance` is the corresponding balance of the number of points that has been
///  requested to be unbonded (the argument of the `unbond` transaction) from the bonded
///  pool.
/// - `points` is the number of points that are issued as a result of `balance` being
/// dissolved into the corresponding unbonding pool.
/// - `era` is the era in which the balance will be unbonded.
/// In the absence of slashing, these values will match. In the presence of slashing, the
/// number of points that are issued in the unbonding pool will be less than the amount
/// requested to be unbonded.
class Unbonded extends Event {
  const Unbonded({
    required this.member,
    required this.poolId,
    required this.balance,
    required this.points,
    required this.era,
  });

  factory Unbonded._decode(_i1.Input input) {
    return Unbonded(
      member: const _i1.U8ArrayCodec(32).decode(input),
      poolId: _i1.U32Codec.codec.decode(input),
      balance: _i1.U128Codec.codec.decode(input),
      points: _i1.U128Codec.codec.decode(input),
      era: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 member;

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt balance;

  /// BalanceOf<T>
  final BigInt points;

  /// EraIndex
  final int era;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Unbonded': {
          'member': member.toList(),
          'poolId': poolId,
          'balance': balance,
          'points': points,
          'era': era,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(member);
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(balance);
    size = size + _i1.U128Codec.codec.sizeHint(points);
    size = size + _i1.U32Codec.codec.sizeHint(era);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      member,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      balance,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      points,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      era,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Unbonded &&
          _i10.listsEqual(
            other.member,
            member,
          ) &&
          other.poolId == poolId &&
          other.balance == balance &&
          other.points == points &&
          other.era == era;

  @override
  int get hashCode => Object.hash(
        member,
        poolId,
        balance,
        points,
        era,
      );
}

/// A member has withdrawn from their pool.
///
/// The given number of `points` have been dissolved in return of `balance`.
///
/// Similar to `Unbonded` event, in the absence of slashing, the ratio of point to balance
/// will be 1.
class Withdrawn extends Event {
  const Withdrawn({
    required this.member,
    required this.poolId,
    required this.balance,
    required this.points,
  });

  factory Withdrawn._decode(_i1.Input input) {
    return Withdrawn(
      member: const _i1.U8ArrayCodec(32).decode(input),
      poolId: _i1.U32Codec.codec.decode(input),
      balance: _i1.U128Codec.codec.decode(input),
      points: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 member;

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt balance;

  /// BalanceOf<T>
  final BigInt points;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Withdrawn': {
          'member': member.toList(),
          'poolId': poolId,
          'balance': balance,
          'points': points,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(member);
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(balance);
    size = size + _i1.U128Codec.codec.sizeHint(points);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      member,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      balance,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      points,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Withdrawn &&
          _i10.listsEqual(
            other.member,
            member,
          ) &&
          other.poolId == poolId &&
          other.balance == balance &&
          other.points == points;

  @override
  int get hashCode => Object.hash(
        member,
        poolId,
        balance,
        points,
      );
}

/// A pool has been destroyed.
class Destroyed extends Event {
  const Destroyed({required this.poolId});

  factory Destroyed._decode(_i1.Input input) {
    return Destroyed(poolId: _i1.U32Codec.codec.decode(input));
  }

  /// PoolId
  final int poolId;

  @override
  Map<String, Map<String, int>> toJson() => {
        'Destroyed': {'poolId': poolId}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      5,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Destroyed && other.poolId == poolId;

  @override
  int get hashCode => poolId.hashCode;
}

/// The state of a pool has changed
class StateChanged extends Event {
  const StateChanged({
    required this.poolId,
    required this.newState,
  });

  factory StateChanged._decode(_i1.Input input) {
    return StateChanged(
      poolId: _i1.U32Codec.codec.decode(input),
      newState: _i4.PoolState.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// PoolState
  final _i4.PoolState newState;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'StateChanged': {
          'poolId': poolId,
          'newState': newState.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i4.PoolState.codec.sizeHint(newState);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      6,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i4.PoolState.codec.encodeTo(
      newState,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is StateChanged &&
          other.poolId == poolId &&
          other.newState == newState;

  @override
  int get hashCode => Object.hash(
        poolId,
        newState,
      );
}

/// A member has been removed from a pool.
///
/// The removal can be voluntary (withdrawn all unbonded funds) or involuntary (kicked).
/// Any funds that are still delegated (i.e. dangling delegation) are released and are
/// represented by `released_balance`.
class MemberRemoved extends Event {
  const MemberRemoved({
    required this.poolId,
    required this.member,
    required this.releasedBalance,
  });

  factory MemberRemoved._decode(_i1.Input input) {
    return MemberRemoved(
      poolId: _i1.U32Codec.codec.decode(input),
      member: const _i1.U8ArrayCodec(32).decode(input),
      releasedBalance: _i1.U128Codec.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// T::AccountId
  final _i3.AccountId32 member;

  /// BalanceOf<T>
  final BigInt releasedBalance;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MemberRemoved': {
          'poolId': poolId,
          'member': member.toList(),
          'releasedBalance': releasedBalance,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + const _i3.AccountId32Codec().sizeHint(member);
    size = size + _i1.U128Codec.codec.sizeHint(releasedBalance);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      7,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      member,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      releasedBalance,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MemberRemoved &&
          other.poolId == poolId &&
          _i10.listsEqual(
            other.member,
            member,
          ) &&
          other.releasedBalance == releasedBalance;

  @override
  int get hashCode => Object.hash(
        poolId,
        member,
        releasedBalance,
      );
}

/// The roles of a pool have been updated to the given new roles. Note that the depositor
/// can never change.
class RolesUpdated extends Event {
  const RolesUpdated({
    this.root,
    this.bouncer,
    this.nominator,
  });

  factory RolesUpdated._decode(_i1.Input input) {
    return RolesUpdated(
      root: const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec())
          .decode(input),
      bouncer: const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec())
          .decode(input),
      nominator: const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec())
          .decode(input),
    );
  }

  /// Option<T::AccountId>
  final _i3.AccountId32? root;

  /// Option<T::AccountId>
  final _i3.AccountId32? bouncer;

  /// Option<T::AccountId>
  final _i3.AccountId32? nominator;

  @override
  Map<String, Map<String, List<int>?>> toJson() => {
        'RolesUpdated': {
          'root': root?.toList(),
          'bouncer': bouncer?.toList(),
          'nominator': nominator?.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec())
            .sizeHint(root);
    size = size +
        const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec())
            .sizeHint(bouncer);
    size = size +
        const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec())
            .sizeHint(nominator);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      8,
      output,
    );
    const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec()).encodeTo(
      root,
      output,
    );
    const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec()).encodeTo(
      bouncer,
      output,
    );
    const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec()).encodeTo(
      nominator,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RolesUpdated &&
          other.root == root &&
          other.bouncer == bouncer &&
          other.nominator == nominator;

  @override
  int get hashCode => Object.hash(
        root,
        bouncer,
        nominator,
      );
}

/// The active balance of pool `pool_id` has been slashed to `balance`.
class PoolSlashed extends Event {
  const PoolSlashed({
    required this.poolId,
    required this.balance,
  });

  factory PoolSlashed._decode(_i1.Input input) {
    return PoolSlashed(
      poolId: _i1.U32Codec.codec.decode(input),
      balance: _i1.U128Codec.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt balance;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PoolSlashed': {
          'poolId': poolId,
          'balance': balance,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(balance);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      9,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      balance,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolSlashed &&
          other.poolId == poolId &&
          other.balance == balance;

  @override
  int get hashCode => Object.hash(
        poolId,
        balance,
      );
}

/// The unbond pool at `era` of pool `pool_id` has been slashed to `balance`.
class UnbondingPoolSlashed extends Event {
  const UnbondingPoolSlashed({
    required this.poolId,
    required this.era,
    required this.balance,
  });

  factory UnbondingPoolSlashed._decode(_i1.Input input) {
    return UnbondingPoolSlashed(
      poolId: _i1.U32Codec.codec.decode(input),
      era: _i1.U32Codec.codec.decode(input),
      balance: _i1.U128Codec.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// EraIndex
  final int era;

  /// BalanceOf<T>
  final BigInt balance;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'UnbondingPoolSlashed': {
          'poolId': poolId,
          'era': era,
          'balance': balance,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U32Codec.codec.sizeHint(era);
    size = size + _i1.U128Codec.codec.sizeHint(balance);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      10,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      era,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      balance,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is UnbondingPoolSlashed &&
          other.poolId == poolId &&
          other.era == era &&
          other.balance == balance;

  @override
  int get hashCode => Object.hash(
        poolId,
        era,
        balance,
      );
}

/// A pool's commission setting has been changed.
class PoolCommissionUpdated extends Event {
  const PoolCommissionUpdated({
    required this.poolId,
    this.current,
  });

  factory PoolCommissionUpdated._decode(_i1.Input input) {
    return PoolCommissionUpdated(
      poolId: _i1.U32Codec.codec.decode(input),
      current: const _i1.OptionCodec<_i5.Tuple2<_i6.Perbill, _i3.AccountId32>>(
          _i5.Tuple2Codec<_i6.Perbill, _i3.AccountId32>(
        _i6.PerbillCodec(),
        _i3.AccountId32Codec(),
      )).decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// Option<(Perbill, T::AccountId)>
  final _i5.Tuple2<_i6.Perbill, _i3.AccountId32>? current;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PoolCommissionUpdated': {
          'poolId': poolId,
          'current': [
            current?.value0,
            current?.value1.toList(),
          ],
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size +
        const _i1.OptionCodec<_i5.Tuple2<_i6.Perbill, _i3.AccountId32>>(
            _i5.Tuple2Codec<_i6.Perbill, _i3.AccountId32>(
          _i6.PerbillCodec(),
          _i3.AccountId32Codec(),
        )).sizeHint(current);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      11,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    const _i1.OptionCodec<_i5.Tuple2<_i6.Perbill, _i3.AccountId32>>(
        _i5.Tuple2Codec<_i6.Perbill, _i3.AccountId32>(
      _i6.PerbillCodec(),
      _i3.AccountId32Codec(),
    )).encodeTo(
      current,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolCommissionUpdated &&
          other.poolId == poolId &&
          other.current == current;

  @override
  int get hashCode => Object.hash(
        poolId,
        current,
      );
}

/// A pool's maximum commission setting has been changed.
class PoolMaxCommissionUpdated extends Event {
  const PoolMaxCommissionUpdated({
    required this.poolId,
    required this.maxCommission,
  });

  factory PoolMaxCommissionUpdated._decode(_i1.Input input) {
    return PoolMaxCommissionUpdated(
      poolId: _i1.U32Codec.codec.decode(input),
      maxCommission: _i1.U32Codec.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// Perbill
  final _i6.Perbill maxCommission;

  @override
  Map<String, Map<String, int>> toJson() => {
        'PoolMaxCommissionUpdated': {
          'poolId': poolId,
          'maxCommission': maxCommission,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + const _i6.PerbillCodec().sizeHint(maxCommission);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      12,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      maxCommission,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolMaxCommissionUpdated &&
          other.poolId == poolId &&
          other.maxCommission == maxCommission;

  @override
  int get hashCode => Object.hash(
        poolId,
        maxCommission,
      );
}

/// A pool's commission `change_rate` has been changed.
class PoolCommissionChangeRateUpdated extends Event {
  const PoolCommissionChangeRateUpdated({
    required this.poolId,
    required this.changeRate,
  });

  factory PoolCommissionChangeRateUpdated._decode(_i1.Input input) {
    return PoolCommissionChangeRateUpdated(
      poolId: _i1.U32Codec.codec.decode(input),
      changeRate: _i7.CommissionChangeRate.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// CommissionChangeRate<BlockNumberFor<T>>
  final _i7.CommissionChangeRate changeRate;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PoolCommissionChangeRateUpdated': {
          'poolId': poolId,
          'changeRate': changeRate.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i7.CommissionChangeRate.codec.sizeHint(changeRate);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      13,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i7.CommissionChangeRate.codec.encodeTo(
      changeRate,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolCommissionChangeRateUpdated &&
          other.poolId == poolId &&
          other.changeRate == changeRate;

  @override
  int get hashCode => Object.hash(
        poolId,
        changeRate,
      );
}

/// Pool commission claim permission has been updated.
class PoolCommissionClaimPermissionUpdated extends Event {
  const PoolCommissionClaimPermissionUpdated({
    required this.poolId,
    this.permission,
  });

  factory PoolCommissionClaimPermissionUpdated._decode(_i1.Input input) {
    return PoolCommissionClaimPermissionUpdated(
      poolId: _i1.U32Codec.codec.decode(input),
      permission: const _i1.OptionCodec<_i8.CommissionClaimPermission>(
              _i8.CommissionClaimPermission.codec)
          .decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// Option<CommissionClaimPermission<T::AccountId>>
  final _i8.CommissionClaimPermission? permission;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PoolCommissionClaimPermissionUpdated': {
          'poolId': poolId,
          'permission': permission?.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size +
        const _i1.OptionCodec<_i8.CommissionClaimPermission>(
                _i8.CommissionClaimPermission.codec)
            .sizeHint(permission);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      14,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    const _i1.OptionCodec<_i8.CommissionClaimPermission>(
            _i8.CommissionClaimPermission.codec)
        .encodeTo(
      permission,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolCommissionClaimPermissionUpdated &&
          other.poolId == poolId &&
          other.permission == permission;

  @override
  int get hashCode => Object.hash(
        poolId,
        permission,
      );
}

/// Pool commission has been claimed.
class PoolCommissionClaimed extends Event {
  const PoolCommissionClaimed({
    required this.poolId,
    required this.commission,
  });

  factory PoolCommissionClaimed._decode(_i1.Input input) {
    return PoolCommissionClaimed(
      poolId: _i1.U32Codec.codec.decode(input),
      commission: _i1.U128Codec.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt commission;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PoolCommissionClaimed': {
          'poolId': poolId,
          'commission': commission,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(commission);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      15,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      commission,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolCommissionClaimed &&
          other.poolId == poolId &&
          other.commission == commission;

  @override
  int get hashCode => Object.hash(
        poolId,
        commission,
      );
}

/// Topped up deficit in frozen ED of the reward pool.
class MinBalanceDeficitAdjusted extends Event {
  const MinBalanceDeficitAdjusted({
    required this.poolId,
    required this.amount,
  });

  factory MinBalanceDeficitAdjusted._decode(_i1.Input input) {
    return MinBalanceDeficitAdjusted(
      poolId: _i1.U32Codec.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MinBalanceDeficitAdjusted': {
          'poolId': poolId,
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      16,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
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
      other is MinBalanceDeficitAdjusted &&
          other.poolId == poolId &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        poolId,
        amount,
      );
}

/// Claimed excess frozen ED of af the reward pool.
class MinBalanceExcessAdjusted extends Event {
  const MinBalanceExcessAdjusted({
    required this.poolId,
    required this.amount,
  });

  factory MinBalanceExcessAdjusted._decode(_i1.Input input) {
    return MinBalanceExcessAdjusted(
      poolId: _i1.U32Codec.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MinBalanceExcessAdjusted': {
          'poolId': poolId,
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      17,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
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
      other is MinBalanceExcessAdjusted &&
          other.poolId == poolId &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        poolId,
        amount,
      );
}

/// A pool member's claim permission has been updated.
class MemberClaimPermissionUpdated extends Event {
  const MemberClaimPermissionUpdated({
    required this.member,
    required this.permission,
  });

  factory MemberClaimPermissionUpdated._decode(_i1.Input input) {
    return MemberClaimPermissionUpdated(
      member: const _i1.U8ArrayCodec(32).decode(input),
      permission: _i9.ClaimPermission.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 member;

  /// ClaimPermission
  final _i9.ClaimPermission permission;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MemberClaimPermissionUpdated': {
          'member': member.toList(),
          'permission': permission.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(member);
    size = size + _i9.ClaimPermission.codec.sizeHint(permission);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      18,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      member,
      output,
    );
    _i9.ClaimPermission.codec.encodeTo(
      permission,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MemberClaimPermissionUpdated &&
          _i10.listsEqual(
            other.member,
            member,
          ) &&
          other.permission == permission;

  @override
  int get hashCode => Object.hash(
        member,
        permission,
      );
}

/// A pool's metadata was updated.
class MetadataUpdated extends Event {
  const MetadataUpdated({
    required this.poolId,
    required this.caller,
  });

  factory MetadataUpdated._decode(_i1.Input input) {
    return MetadataUpdated(
      poolId: _i1.U32Codec.codec.decode(input),
      caller: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// T::AccountId
  final _i3.AccountId32 caller;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MetadataUpdated': {
          'poolId': poolId,
          'caller': caller.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + const _i3.AccountId32Codec().sizeHint(caller);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      19,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      caller,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MetadataUpdated &&
          other.poolId == poolId &&
          _i10.listsEqual(
            other.caller,
            caller,
          );

  @override
  int get hashCode => Object.hash(
        poolId,
        caller,
      );
}

/// A pool's nominating account (or the pool's root account) has nominated a validator set
/// on behalf of the pool.
class PoolNominationMade extends Event {
  const PoolNominationMade({
    required this.poolId,
    required this.caller,
  });

  factory PoolNominationMade._decode(_i1.Input input) {
    return PoolNominationMade(
      poolId: _i1.U32Codec.codec.decode(input),
      caller: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// T::AccountId
  final _i3.AccountId32 caller;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PoolNominationMade': {
          'poolId': poolId,
          'caller': caller.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + const _i3.AccountId32Codec().sizeHint(caller);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      20,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      caller,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolNominationMade &&
          other.poolId == poolId &&
          _i10.listsEqual(
            other.caller,
            caller,
          );

  @override
  int get hashCode => Object.hash(
        poolId,
        caller,
      );
}

/// The pool is chilled i.e. no longer nominating.
class PoolNominatorChilled extends Event {
  const PoolNominatorChilled({
    required this.poolId,
    required this.caller,
  });

  factory PoolNominatorChilled._decode(_i1.Input input) {
    return PoolNominatorChilled(
      poolId: _i1.U32Codec.codec.decode(input),
      caller: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// PoolId
  final int poolId;

  /// T::AccountId
  final _i3.AccountId32 caller;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'PoolNominatorChilled': {
          'poolId': poolId,
          'caller': caller.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poolId);
    size = size + const _i3.AccountId32Codec().sizeHint(caller);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      21,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poolId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      caller,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolNominatorChilled &&
          other.poolId == poolId &&
          _i10.listsEqual(
            other.caller,
            caller,
          );

  @override
  int get hashCode => Object.hash(
        poolId,
        caller,
      );
}

/// Global parameters regulating nomination pools have been updated.
class GlobalParamsUpdated extends Event {
  const GlobalParamsUpdated({
    required this.minJoinBond,
    required this.minCreateBond,
    this.maxPools,
    this.maxMembers,
    this.maxMembersPerPool,
    this.globalMaxCommission,
  });

  factory GlobalParamsUpdated._decode(_i1.Input input) {
    return GlobalParamsUpdated(
      minJoinBond: _i1.U128Codec.codec.decode(input),
      minCreateBond: _i1.U128Codec.codec.decode(input),
      maxPools: const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
      maxMembers: const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
      maxMembersPerPool:
          const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
      globalMaxCommission:
          const _i1.OptionCodec<_i6.Perbill>(_i6.PerbillCodec()).decode(input),
    );
  }

  /// BalanceOf<T>
  final BigInt minJoinBond;

  /// BalanceOf<T>
  final BigInt minCreateBond;

  /// Option<u32>
  final int? maxPools;

  /// Option<u32>
  final int? maxMembers;

  /// Option<u32>
  final int? maxMembersPerPool;

  /// Option<Perbill>
  final _i6.Perbill? globalMaxCommission;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'GlobalParamsUpdated': {
          'minJoinBond': minJoinBond,
          'minCreateBond': minCreateBond,
          'maxPools': maxPools,
          'maxMembers': maxMembers,
          'maxMembersPerPool': maxMembersPerPool,
          'globalMaxCommission': globalMaxCommission,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U128Codec.codec.sizeHint(minJoinBond);
    size = size + _i1.U128Codec.codec.sizeHint(minCreateBond);
    size = size +
        const _i1.OptionCodec<int>(_i1.U32Codec.codec).sizeHint(maxPools);
    size = size +
        const _i1.OptionCodec<int>(_i1.U32Codec.codec).sizeHint(maxMembers);
    size = size +
        const _i1.OptionCodec<int>(_i1.U32Codec.codec)
            .sizeHint(maxMembersPerPool);
    size = size +
        const _i1.OptionCodec<_i6.Perbill>(_i6.PerbillCodec())
            .sizeHint(globalMaxCommission);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      22,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      minJoinBond,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      minCreateBond,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      maxPools,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      maxMembers,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      maxMembersPerPool,
      output,
    );
    const _i1.OptionCodec<_i6.Perbill>(_i6.PerbillCodec()).encodeTo(
      globalMaxCommission,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is GlobalParamsUpdated &&
          other.minJoinBond == minJoinBond &&
          other.minCreateBond == minCreateBond &&
          other.maxPools == maxPools &&
          other.maxMembers == maxMembers &&
          other.maxMembersPerPool == maxMembersPerPool &&
          other.globalMaxCommission == globalMaxCommission;

  @override
  int get hashCode => Object.hash(
        minJoinBond,
        minCreateBond,
        maxPools,
        maxMembers,
        maxMembersPerPool,
        globalMaxCommission,
      );
}
