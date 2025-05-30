// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i6;

import '../../sp_core/crypto/account_id32.dart' as _i3;
import '../tally.dart' as _i5;
import '../vote_record.dart' as _i4;

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

  MemberAdded memberAdded({required _i3.AccountId32 who}) {
    return MemberAdded(who: who);
  }

  RankChanged rankChanged({
    required _i3.AccountId32 who,
    required int rank,
  }) {
    return RankChanged(
      who: who,
      rank: rank,
    );
  }

  MemberRemoved memberRemoved({
    required _i3.AccountId32 who,
    required int rank,
  }) {
    return MemberRemoved(
      who: who,
      rank: rank,
    );
  }

  Voted voted({
    required _i3.AccountId32 who,
    required int poll,
    required _i4.VoteRecord vote,
    required _i5.Tally tally,
  }) {
    return Voted(
      who: who,
      poll: poll,
      vote: vote,
      tally: tally,
    );
  }

  MemberExchanged memberExchanged({
    required _i3.AccountId32 who,
    required _i3.AccountId32 newWho,
  }) {
    return MemberExchanged(
      who: who,
      newWho: newWho,
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
        return MemberAdded._decode(input);
      case 1:
        return RankChanged._decode(input);
      case 2:
        return MemberRemoved._decode(input);
      case 3:
        return Voted._decode(input);
      case 4:
        return MemberExchanged._decode(input);
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
      case MemberAdded:
        (value as MemberAdded).encodeTo(output);
        break;
      case RankChanged:
        (value as RankChanged).encodeTo(output);
        break;
      case MemberRemoved:
        (value as MemberRemoved).encodeTo(output);
        break;
      case Voted:
        (value as Voted).encodeTo(output);
        break;
      case MemberExchanged:
        (value as MemberExchanged).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case MemberAdded:
        return (value as MemberAdded)._sizeHint();
      case RankChanged:
        return (value as RankChanged)._sizeHint();
      case MemberRemoved:
        return (value as MemberRemoved)._sizeHint();
      case Voted:
        return (value as Voted)._sizeHint();
      case MemberExchanged:
        return (value as MemberExchanged)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A member `who` has been added.
class MemberAdded extends Event {
  const MemberAdded({required this.who});

  factory MemberAdded._decode(_i1.Input input) {
    return MemberAdded(who: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'MemberAdded': {'who': who.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
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
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MemberAdded &&
          _i6.listsEqual(
            other.who,
            who,
          );

  @override
  int get hashCode => who.hashCode;
}

/// The member `who`se rank has been changed to the given `rank`.
class RankChanged extends Event {
  const RankChanged({
    required this.who,
    required this.rank,
  });

  factory RankChanged._decode(_i1.Input input) {
    return RankChanged(
      who: const _i1.U8ArrayCodec(32).decode(input),
      rank: _i1.U16Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// Rank
  final int rank;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'RankChanged': {
          'who': who.toList(),
          'rank': rank,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i1.U16Codec.codec.sizeHint(rank);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
    _i1.U16Codec.codec.encodeTo(
      rank,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RankChanged &&
          _i6.listsEqual(
            other.who,
            who,
          ) &&
          other.rank == rank;

  @override
  int get hashCode => Object.hash(
        who,
        rank,
      );
}

/// The member `who` of given `rank` has been removed from the collective.
class MemberRemoved extends Event {
  const MemberRemoved({
    required this.who,
    required this.rank,
  });

  factory MemberRemoved._decode(_i1.Input input) {
    return MemberRemoved(
      who: const _i1.U8ArrayCodec(32).decode(input),
      rank: _i1.U16Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// Rank
  final int rank;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MemberRemoved': {
          'who': who.toList(),
          'rank': rank,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i1.U16Codec.codec.sizeHint(rank);
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
    _i1.U16Codec.codec.encodeTo(
      rank,
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
          _i6.listsEqual(
            other.who,
            who,
          ) &&
          other.rank == rank;

  @override
  int get hashCode => Object.hash(
        who,
        rank,
      );
}

/// The member `who` has voted for the `poll` with the given `vote` leading to an updated
/// `tally`.
class Voted extends Event {
  const Voted({
    required this.who,
    required this.poll,
    required this.vote,
    required this.tally,
  });

  factory Voted._decode(_i1.Input input) {
    return Voted(
      who: const _i1.U8ArrayCodec(32).decode(input),
      poll: _i1.U32Codec.codec.decode(input),
      vote: _i4.VoteRecord.codec.decode(input),
      tally: _i5.Tally.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// PollIndexOf<T, I>
  final int poll;

  /// VoteRecord
  final _i4.VoteRecord vote;

  /// TallyOf<T, I>
  final _i5.Tally tally;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Voted': {
          'who': who.toList(),
          'poll': poll,
          'vote': vote.toJson(),
          'tally': tally.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i1.U32Codec.codec.sizeHint(poll);
    size = size + _i4.VoteRecord.codec.sizeHint(vote);
    size = size + _i5.Tally.codec.sizeHint(tally);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      poll,
      output,
    );
    _i4.VoteRecord.codec.encodeTo(
      vote,
      output,
    );
    _i5.Tally.codec.encodeTo(
      tally,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Voted &&
          _i6.listsEqual(
            other.who,
            who,
          ) &&
          other.poll == poll &&
          other.vote == vote &&
          other.tally == tally;

  @override
  int get hashCode => Object.hash(
        who,
        poll,
        vote,
        tally,
      );
}

/// The member `who` had their `AccountId` changed to `new_who`.
class MemberExchanged extends Event {
  const MemberExchanged({
    required this.who,
    required this.newWho,
  });

  factory MemberExchanged._decode(_i1.Input input) {
    return MemberExchanged(
      who: const _i1.U8ArrayCodec(32).decode(input),
      newWho: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// T::AccountId
  final _i3.AccountId32 newWho;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'MemberExchanged': {
          'who': who.toList(),
          'newWho': newWho.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + const _i3.AccountId32Codec().sizeHint(newWho);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
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
      other is MemberExchanged &&
          _i6.listsEqual(
            other.who,
            who,
          ) &&
          _i6.listsEqual(
            other.newWho,
            newWho,
          );

  @override
  int get hashCode => Object.hash(
        who,
        newWho,
      );
}
