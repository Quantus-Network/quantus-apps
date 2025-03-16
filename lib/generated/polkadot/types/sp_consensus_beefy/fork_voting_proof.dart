// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i5;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../sp_mmr_primitives/ancestry_proof.dart' as _i3;
import '../sp_runtime/generic/header/header.dart' as _i4;
import 'vote_message.dart' as _i2;

class ForkVotingProof {
  const ForkVotingProof({
    required this.vote,
    required this.ancestryProof,
    required this.header,
  });

  factory ForkVotingProof.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// VoteMessage<Header::Number, Id, Id::Signature>
  final _i2.VoteMessage vote;

  /// AncestryProof
  final _i3.AncestryProof ancestryProof;

  /// Header
  final _i4.Header header;

  static const $ForkVotingProofCodec codec = $ForkVotingProofCodec();

  _i5.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, Map<String, dynamic>> toJson() => {
        'vote': vote.toJson(),
        'ancestryProof': ancestryProof.toJson(),
        'header': header.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ForkVotingProof &&
          other.vote == vote &&
          other.ancestryProof == ancestryProof &&
          other.header == header;

  @override
  int get hashCode => Object.hash(
        vote,
        ancestryProof,
        header,
      );
}

class $ForkVotingProofCodec with _i1.Codec<ForkVotingProof> {
  const $ForkVotingProofCodec();

  @override
  void encodeTo(
    ForkVotingProof obj,
    _i1.Output output,
  ) {
    _i2.VoteMessage.codec.encodeTo(
      obj.vote,
      output,
    );
    _i3.AncestryProof.codec.encodeTo(
      obj.ancestryProof,
      output,
    );
    _i4.Header.codec.encodeTo(
      obj.header,
      output,
    );
  }

  @override
  ForkVotingProof decode(_i1.Input input) {
    return ForkVotingProof(
      vote: _i2.VoteMessage.codec.decode(input),
      ancestryProof: _i3.AncestryProof.codec.decode(input),
      header: _i4.Header.codec.decode(input),
    );
  }

  @override
  int sizeHint(ForkVotingProof obj) {
    int size = 0;
    size = size + _i2.VoteMessage.codec.sizeHint(obj.vote);
    size = size + _i3.AncestryProof.codec.sizeHint(obj.ancestryProof);
    size = size + _i4.Header.codec.sizeHint(obj.header);
    return size;
  }
}
