// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../sp_core/crypto/account_id32.dart' as _i3;
import '../vote/account_vote.dart' as _i4;

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

  Map<String, dynamic> toJson();
}

class $Event {
  const $Event();

  Delegated delegated(
    _i3.AccountId32 value0,
    _i3.AccountId32 value1,
  ) {
    return Delegated(
      value0,
      value1,
    );
  }

  Undelegated undelegated(_i3.AccountId32 value0) {
    return Undelegated(value0);
  }

  Voted voted({
    required _i3.AccountId32 who,
    required _i4.AccountVote vote,
  }) {
    return Voted(
      who: who,
      vote: vote,
    );
  }

  VoteRemoved voteRemoved({
    required _i3.AccountId32 who,
    required _i4.AccountVote vote,
  }) {
    return VoteRemoved(
      who: who,
      vote: vote,
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
        return Delegated._decode(input);
      case 1:
        return Undelegated._decode(input);
      case 2:
        return Voted._decode(input);
      case 3:
        return VoteRemoved._decode(input);
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
      case Delegated:
        (value as Delegated).encodeTo(output);
        break;
      case Undelegated:
        (value as Undelegated).encodeTo(output);
        break;
      case Voted:
        (value as Voted).encodeTo(output);
        break;
      case VoteRemoved:
        (value as VoteRemoved).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case Delegated:
        return (value as Delegated)._sizeHint();
      case Undelegated:
        return (value as Undelegated)._sizeHint();
      case Voted:
        return (value as Voted)._sizeHint();
      case VoteRemoved:
        return (value as VoteRemoved)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// An account has delegated their vote to another account. \[who, target\]
class Delegated extends Event {
  const Delegated(
    this.value0,
    this.value1,
  );

  factory Delegated._decode(_i1.Input input) {
    return Delegated(
      const _i1.U8ArrayCodec(32).decode(input),
      const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 value0;

  /// T::AccountId
  final _i3.AccountId32 value1;

  @override
  Map<String, List<List<int>>> toJson() => {
        'Delegated': [
          value0.toList(),
          value1.toList(),
        ]
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(value0);
    size = size + const _i3.AccountId32Codec().sizeHint(value1);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      value0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      value1,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Delegated &&
          _i5.listsEqual(
            other.value0,
            value0,
          ) &&
          _i5.listsEqual(
            other.value1,
            value1,
          );

  @override
  int get hashCode => Object.hash(
        value0,
        value1,
      );
}

/// An \[account\] has cancelled a previous delegation operation.
class Undelegated extends Event {
  const Undelegated(this.value0);

  factory Undelegated._decode(_i1.Input input) {
    return Undelegated(const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i3.AccountId32 value0;

  @override
  Map<String, List<int>> toJson() => {'Undelegated': value0.toList()};

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Undelegated &&
          _i5.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

/// An account that has voted
class Voted extends Event {
  const Voted({
    required this.who,
    required this.vote,
  });

  factory Voted._decode(_i1.Input input) {
    return Voted(
      who: const _i1.U8ArrayCodec(32).decode(input),
      vote: _i4.AccountVote.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// AccountVote<BalanceOf<T, I>>
  final _i4.AccountVote vote;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Voted': {
          'who': who.toList(),
          'vote': vote.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i4.AccountVote.codec.sizeHint(vote);
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
    _i4.AccountVote.codec.encodeTo(
      vote,
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
          _i5.listsEqual(
            other.who,
            who,
          ) &&
          other.vote == vote;

  @override
  int get hashCode => Object.hash(
        who,
        vote,
      );
}

/// A vote that been removed
class VoteRemoved extends Event {
  const VoteRemoved({
    required this.who,
    required this.vote,
  });

  factory VoteRemoved._decode(_i1.Input input) {
    return VoteRemoved(
      who: const _i1.U8ArrayCodec(32).decode(input),
      vote: _i4.AccountVote.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// AccountVote<BalanceOf<T, I>>
  final _i4.AccountVote vote;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'VoteRemoved': {
          'who': who.toList(),
          'vote': vote.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i4.AccountVote.codec.sizeHint(vote);
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
    _i4.AccountVote.codec.encodeTo(
      vote,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is VoteRemoved &&
          _i5.listsEqual(
            other.who,
            who,
          ) &&
          other.vote == vote;

  @override
  int get hashCode => Object.hash(
        who,
        vote,
      );
}
