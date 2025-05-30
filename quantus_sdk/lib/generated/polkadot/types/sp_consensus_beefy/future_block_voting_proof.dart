// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;

import 'vote_message.dart' as _i2;

class FutureBlockVotingProof {
  const FutureBlockVotingProof({required this.vote});

  factory FutureBlockVotingProof.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// VoteMessage<Number, Id, Id::Signature>
  final _i2.VoteMessage vote;

  static const $FutureBlockVotingProofCodec codec =
      $FutureBlockVotingProofCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, Map<String, dynamic>> toJson() => {'vote': vote.toJson()};

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is FutureBlockVotingProof && other.vote == vote;

  @override
  int get hashCode => vote.hashCode;
}

class $FutureBlockVotingProofCodec with _i1.Codec<FutureBlockVotingProof> {
  const $FutureBlockVotingProofCodec();

  @override
  void encodeTo(
    FutureBlockVotingProof obj,
    _i1.Output output,
  ) {
    _i2.VoteMessage.codec.encodeTo(
      obj.vote,
      output,
    );
  }

  @override
  FutureBlockVotingProof decode(_i1.Input input) {
    return FutureBlockVotingProof(vote: _i2.VoteMessage.codec.decode(input));
  }

  @override
  int sizeHint(FutureBlockVotingProof obj) {
    int size = 0;
    size = size + _i2.VoteMessage.codec.sizeHint(obj.vote);
    return size;
  }
}
