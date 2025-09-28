// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

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

  Map<String, Map<String, dynamic>> toJson();
}

class $Call {
  const $Call();

  AddMember addMember({required _i3.MultiAddress who}) {
    return AddMember(who: who);
  }

  PromoteMember promoteMember({required _i3.MultiAddress who}) {
    return PromoteMember(who: who);
  }

  DemoteMember demoteMember({required _i3.MultiAddress who}) {
    return DemoteMember(who: who);
  }

  RemoveMember removeMember({
    required _i3.MultiAddress who,
    required int minRank,
  }) {
    return RemoveMember(
      who: who,
      minRank: minRank,
    );
  }

  Vote vote({
    required int poll,
    required bool aye,
  }) {
    return Vote(
      poll: poll,
      aye: aye,
    );
  }

  CleanupPoll cleanupPoll({
    required int pollIndex,
    required int max,
  }) {
    return CleanupPoll(
      pollIndex: pollIndex,
      max: max,
    );
  }

  ExchangeMember exchangeMember({
    required _i3.MultiAddress who,
    required _i3.MultiAddress newWho,
  }) {
    return ExchangeMember(
      who: who,
      newWho: newWho,
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
        return AddMember._decode(input);
      case 1:
        return PromoteMember._decode(input);
      case 2:
        return DemoteMember._decode(input);
      case 3:
        return RemoveMember._decode(input);
      case 4:
        return Vote._decode(input);
      case 5:
        return CleanupPoll._decode(input);
      case 6:
        return ExchangeMember._decode(input);
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
      case AddMember:
        (value as AddMember).encodeTo(output);
        break;
      case PromoteMember:
        (value as PromoteMember).encodeTo(output);
        break;
      case DemoteMember:
        (value as DemoteMember).encodeTo(output);
        break;
      case RemoveMember:
        (value as RemoveMember).encodeTo(output);
        break;
      case Vote:
        (value as Vote).encodeTo(output);
        break;
      case CleanupPoll:
        (value as CleanupPoll).encodeTo(output);
        break;
      case ExchangeMember:
        (value as ExchangeMember).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case AddMember:
        return (value as AddMember)._sizeHint();
      case PromoteMember:
        return (value as PromoteMember)._sizeHint();
      case DemoteMember:
        return (value as DemoteMember)._sizeHint();
      case RemoveMember:
        return (value as RemoveMember)._sizeHint();
      case Vote:
        return (value as Vote)._sizeHint();
      case CleanupPoll:
        return (value as CleanupPoll)._sizeHint();
      case ExchangeMember:
        return (value as ExchangeMember)._sizeHint();
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Introduce a new member.
///
/// - `origin`: Must be the `AddOrigin`.
/// - `who`: Account of non-member which will become a member.
///
/// Weight: `O(1)`
class AddMember extends Call {
  const AddMember({required this.who});

  factory AddMember._decode(_i1.Input input) {
    return AddMember(who: _i3.MultiAddress.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress who;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'add_member': {'who': who.toJson()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(who);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      who,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AddMember && other.who == who;

  @override
  int get hashCode => who.hashCode;
}

/// Increment the rank of an existing member by one.
///
/// - `origin`: Must be the `PromoteOrigin`.
/// - `who`: Account of existing member.
///
/// Weight: `O(1)`
class PromoteMember extends Call {
  const PromoteMember({required this.who});

  factory PromoteMember._decode(_i1.Input input) {
    return PromoteMember(who: _i3.MultiAddress.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress who;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'promote_member': {'who': who.toJson()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(who);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      who,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PromoteMember && other.who == who;

  @override
  int get hashCode => who.hashCode;
}

/// Decrement the rank of an existing member by one. If the member is already at rank zero,
/// then they are removed entirely.
///
/// - `origin`: Must be the `DemoteOrigin`.
/// - `who`: Account of existing member of rank greater than zero.
///
/// Weight: `O(1)`, less if the member's index is highest in its rank.
class DemoteMember extends Call {
  const DemoteMember({required this.who});

  factory DemoteMember._decode(_i1.Input input) {
    return DemoteMember(who: _i3.MultiAddress.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress who;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'demote_member': {'who': who.toJson()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(who);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      who,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is DemoteMember && other.who == who;

  @override
  int get hashCode => who.hashCode;
}

/// Remove the member entirely.
///
/// - `origin`: Must be the `RemoveOrigin`.
/// - `who`: Account of existing member of rank greater than zero.
/// - `min_rank`: The rank of the member or greater.
///
/// Weight: `O(min_rank)`.
class RemoveMember extends Call {
  const RemoveMember({
    required this.who,
    required this.minRank,
  });

  factory RemoveMember._decode(_i1.Input input) {
    return RemoveMember(
      who: _i3.MultiAddress.codec.decode(input),
      minRank: _i1.U16Codec.codec.decode(input),
    );
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress who;

  /// Rank
  final int minRank;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'remove_member': {
          'who': who.toJson(),
          'minRank': minRank,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(who);
    size = size + _i1.U16Codec.codec.sizeHint(minRank);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      who,
      output,
    );
    _i1.U16Codec.codec.encodeTo(
      minRank,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RemoveMember && other.who == who && other.minRank == minRank;

  @override
  int get hashCode => Object.hash(
        who,
        minRank,
      );
}

/// Add an aye or nay vote for the sender to the given proposal.
///
/// - `origin`: Must be `Signed` by a member account.
/// - `poll`: Index of a poll which is ongoing.
/// - `aye`: `true` if the vote is to approve the proposal, `false` otherwise.
///
/// Transaction fees are be waived if the member is voting on any particular proposal
/// for the first time and the call is successful. Subsequent vote changes will charge a
/// fee.
///
/// Weight: `O(1)`, less if there was no previous vote on the poll by the member.
class Vote extends Call {
  const Vote({
    required this.poll,
    required this.aye,
  });

  factory Vote._decode(_i1.Input input) {
    return Vote(
      poll: _i1.U32Codec.codec.decode(input),
      aye: _i1.BoolCodec.codec.decode(input),
    );
  }

  /// PollIndexOf<T, I>
  final int poll;

  /// bool
  final bool aye;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'vote': {
          'poll': poll,
          'aye': aye,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(poll);
    size = size + _i1.BoolCodec.codec.sizeHint(aye);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poll,
      output,
    );
    _i1.BoolCodec.codec.encodeTo(
      aye,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Vote && other.poll == poll && other.aye == aye;

  @override
  int get hashCode => Object.hash(
        poll,
        aye,
      );
}

/// Remove votes from the given poll. It must have ended.
///
/// - `origin`: Must be `Signed` by any account.
/// - `poll_index`: Index of a poll which is completed and for which votes continue to
///  exist.
/// - `max`: Maximum number of vote items from remove in this call.
///
/// Transaction fees are waived if the operation is successful.
///
/// Weight `O(max)` (less if there are fewer items to remove than `max`).
class CleanupPoll extends Call {
  const CleanupPoll({
    required this.pollIndex,
    required this.max,
  });

  factory CleanupPoll._decode(_i1.Input input) {
    return CleanupPoll(
      pollIndex: _i1.U32Codec.codec.decode(input),
      max: _i1.U32Codec.codec.decode(input),
    );
  }

  /// PollIndexOf<T, I>
  final int pollIndex;

  /// u32
  final int max;

  @override
  Map<String, Map<String, int>> toJson() => {
        'cleanup_poll': {
          'pollIndex': pollIndex,
          'max': max,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(pollIndex);
    size = size + _i1.U32Codec.codec.sizeHint(max);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      5,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      pollIndex,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      max,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CleanupPoll && other.pollIndex == pollIndex && other.max == max;

  @override
  int get hashCode => Object.hash(
        pollIndex,
        max,
      );
}

/// Exchanges a member with a new account and the same existing rank.
///
/// - `origin`: Must be the `ExchangeOrigin`.
/// - `who`: Account of existing member of rank greater than zero to be exchanged.
/// - `new_who`: New Account of existing member of rank greater than zero to exchanged to.
class ExchangeMember extends Call {
  const ExchangeMember({
    required this.who,
    required this.newWho,
  });

  factory ExchangeMember._decode(_i1.Input input) {
    return ExchangeMember(
      who: _i3.MultiAddress.codec.decode(input),
      newWho: _i3.MultiAddress.codec.decode(input),
    );
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress who;

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress newWho;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'exchange_member': {
          'who': who.toJson(),
          'newWho': newWho.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(who);
    size = size + _i3.MultiAddress.codec.sizeHint(newWho);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      6,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      who,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      newWho,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ExchangeMember && other.who == who && other.newWho == newWho;

  @override
  int get hashCode => Object.hash(
        who,
        newWho,
      );
}
