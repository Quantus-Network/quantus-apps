// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../../sp_consensus_beefy/double_voting_proof.dart' as _i3;
import '../../sp_consensus_beefy/fork_voting_proof.dart' as _i5;
import '../../sp_consensus_beefy/future_block_voting_proof.dart' as _i6;
import '../../sp_session/membership_proof.dart' as _i4;

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

  ReportDoubleVoting reportDoubleVoting({
    required _i3.DoubleVotingProof equivocationProof,
    required _i4.MembershipProof keyOwnerProof,
  }) {
    return ReportDoubleVoting(
      equivocationProof: equivocationProof,
      keyOwnerProof: keyOwnerProof,
    );
  }

  ReportDoubleVotingUnsigned reportDoubleVotingUnsigned({
    required _i3.DoubleVotingProof equivocationProof,
    required _i4.MembershipProof keyOwnerProof,
  }) {
    return ReportDoubleVotingUnsigned(
      equivocationProof: equivocationProof,
      keyOwnerProof: keyOwnerProof,
    );
  }

  SetNewGenesis setNewGenesis({required int delayInBlocks}) {
    return SetNewGenesis(delayInBlocks: delayInBlocks);
  }

  ReportForkVoting reportForkVoting({
    required _i5.ForkVotingProof equivocationProof,
    required _i4.MembershipProof keyOwnerProof,
  }) {
    return ReportForkVoting(
      equivocationProof: equivocationProof,
      keyOwnerProof: keyOwnerProof,
    );
  }

  ReportForkVotingUnsigned reportForkVotingUnsigned({
    required _i5.ForkVotingProof equivocationProof,
    required _i4.MembershipProof keyOwnerProof,
  }) {
    return ReportForkVotingUnsigned(
      equivocationProof: equivocationProof,
      keyOwnerProof: keyOwnerProof,
    );
  }

  ReportFutureBlockVoting reportFutureBlockVoting({
    required _i6.FutureBlockVotingProof equivocationProof,
    required _i4.MembershipProof keyOwnerProof,
  }) {
    return ReportFutureBlockVoting(
      equivocationProof: equivocationProof,
      keyOwnerProof: keyOwnerProof,
    );
  }

  ReportFutureBlockVotingUnsigned reportFutureBlockVotingUnsigned({
    required _i6.FutureBlockVotingProof equivocationProof,
    required _i4.MembershipProof keyOwnerProof,
  }) {
    return ReportFutureBlockVotingUnsigned(
      equivocationProof: equivocationProof,
      keyOwnerProof: keyOwnerProof,
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
        return ReportDoubleVoting._decode(input);
      case 1:
        return ReportDoubleVotingUnsigned._decode(input);
      case 2:
        return SetNewGenesis._decode(input);
      case 3:
        return ReportForkVoting._decode(input);
      case 4:
        return ReportForkVotingUnsigned._decode(input);
      case 5:
        return ReportFutureBlockVoting._decode(input);
      case 6:
        return ReportFutureBlockVotingUnsigned._decode(input);
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
      case ReportDoubleVoting:
        (value as ReportDoubleVoting).encodeTo(output);
        break;
      case ReportDoubleVotingUnsigned:
        (value as ReportDoubleVotingUnsigned).encodeTo(output);
        break;
      case SetNewGenesis:
        (value as SetNewGenesis).encodeTo(output);
        break;
      case ReportForkVoting:
        (value as ReportForkVoting).encodeTo(output);
        break;
      case ReportForkVotingUnsigned:
        (value as ReportForkVotingUnsigned).encodeTo(output);
        break;
      case ReportFutureBlockVoting:
        (value as ReportFutureBlockVoting).encodeTo(output);
        break;
      case ReportFutureBlockVotingUnsigned:
        (value as ReportFutureBlockVotingUnsigned).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case ReportDoubleVoting:
        return (value as ReportDoubleVoting)._sizeHint();
      case ReportDoubleVotingUnsigned:
        return (value as ReportDoubleVotingUnsigned)._sizeHint();
      case SetNewGenesis:
        return (value as SetNewGenesis)._sizeHint();
      case ReportForkVoting:
        return (value as ReportForkVoting)._sizeHint();
      case ReportForkVotingUnsigned:
        return (value as ReportForkVotingUnsigned)._sizeHint();
      case ReportFutureBlockVoting:
        return (value as ReportFutureBlockVoting)._sizeHint();
      case ReportFutureBlockVotingUnsigned:
        return (value as ReportFutureBlockVotingUnsigned)._sizeHint();
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Report voter equivocation/misbehavior. This method will verify the
/// equivocation proof and validate the given key ownership proof
/// against the extracted offender. If both are valid, the offence
/// will be reported.
class ReportDoubleVoting extends Call {
  const ReportDoubleVoting({
    required this.equivocationProof,
    required this.keyOwnerProof,
  });

  factory ReportDoubleVoting._decode(_i1.Input input) {
    return ReportDoubleVoting(
      equivocationProof: _i3.DoubleVotingProof.codec.decode(input),
      keyOwnerProof: _i4.MembershipProof.codec.decode(input),
    );
  }

  /// Box<DoubleVotingProof<BlockNumberFor<T>, T::BeefyId,<T::BeefyId
  ///as RuntimeAppPublic>::Signature,>,>
  final _i3.DoubleVotingProof equivocationProof;

  /// T::KeyOwnerProof
  final _i4.MembershipProof keyOwnerProof;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'report_double_voting': {
          'equivocationProof': equivocationProof.toJson(),
          'keyOwnerProof': keyOwnerProof.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.DoubleVotingProof.codec.sizeHint(equivocationProof);
    size = size + _i4.MembershipProof.codec.sizeHint(keyOwnerProof);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i3.DoubleVotingProof.codec.encodeTo(
      equivocationProof,
      output,
    );
    _i4.MembershipProof.codec.encodeTo(
      keyOwnerProof,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReportDoubleVoting &&
          other.equivocationProof == equivocationProof &&
          other.keyOwnerProof == keyOwnerProof;

  @override
  int get hashCode => Object.hash(
        equivocationProof,
        keyOwnerProof,
      );
}

/// Report voter equivocation/misbehavior. This method will verify the
/// equivocation proof and validate the given key ownership proof
/// against the extracted offender. If both are valid, the offence
/// will be reported.
///
/// This extrinsic must be called unsigned and it is expected that only
/// block authors will call it (validated in `ValidateUnsigned`), as such
/// if the block author is defined it will be defined as the equivocation
/// reporter.
class ReportDoubleVotingUnsigned extends Call {
  const ReportDoubleVotingUnsigned({
    required this.equivocationProof,
    required this.keyOwnerProof,
  });

  factory ReportDoubleVotingUnsigned._decode(_i1.Input input) {
    return ReportDoubleVotingUnsigned(
      equivocationProof: _i3.DoubleVotingProof.codec.decode(input),
      keyOwnerProof: _i4.MembershipProof.codec.decode(input),
    );
  }

  /// Box<DoubleVotingProof<BlockNumberFor<T>, T::BeefyId,<T::BeefyId
  ///as RuntimeAppPublic>::Signature,>,>
  final _i3.DoubleVotingProof equivocationProof;

  /// T::KeyOwnerProof
  final _i4.MembershipProof keyOwnerProof;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'report_double_voting_unsigned': {
          'equivocationProof': equivocationProof.toJson(),
          'keyOwnerProof': keyOwnerProof.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.DoubleVotingProof.codec.sizeHint(equivocationProof);
    size = size + _i4.MembershipProof.codec.sizeHint(keyOwnerProof);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i3.DoubleVotingProof.codec.encodeTo(
      equivocationProof,
      output,
    );
    _i4.MembershipProof.codec.encodeTo(
      keyOwnerProof,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReportDoubleVotingUnsigned &&
          other.equivocationProof == equivocationProof &&
          other.keyOwnerProof == keyOwnerProof;

  @override
  int get hashCode => Object.hash(
        equivocationProof,
        keyOwnerProof,
      );
}

/// Reset BEEFY consensus by setting a new BEEFY genesis at `delay_in_blocks` blocks in the
/// future.
///
/// Note: `delay_in_blocks` has to be at least 1.
class SetNewGenesis extends Call {
  const SetNewGenesis({required this.delayInBlocks});

  factory SetNewGenesis._decode(_i1.Input input) {
    return SetNewGenesis(delayInBlocks: _i1.U32Codec.codec.decode(input));
  }

  /// BlockNumberFor<T>
  final int delayInBlocks;

  @override
  Map<String, Map<String, int>> toJson() => {
        'set_new_genesis': {'delayInBlocks': delayInBlocks}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(delayInBlocks);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      delayInBlocks,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is SetNewGenesis && other.delayInBlocks == delayInBlocks;

  @override
  int get hashCode => delayInBlocks.hashCode;
}

/// Report fork voting equivocation. This method will verify the equivocation proof
/// and validate the given key ownership proof against the extracted offender.
/// If both are valid, the offence will be reported.
class ReportForkVoting extends Call {
  const ReportForkVoting({
    required this.equivocationProof,
    required this.keyOwnerProof,
  });

  factory ReportForkVoting._decode(_i1.Input input) {
    return ReportForkVoting(
      equivocationProof: _i5.ForkVotingProof.codec.decode(input),
      keyOwnerProof: _i4.MembershipProof.codec.decode(input),
    );
  }

  /// Box<ForkVotingProof<HeaderFor<T>, T::BeefyId,<T::AncestryHelper
  ///as AncestryHelper<HeaderFor<T>>>::Proof,>,>
  final _i5.ForkVotingProof equivocationProof;

  /// T::KeyOwnerProof
  final _i4.MembershipProof keyOwnerProof;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'report_fork_voting': {
          'equivocationProof': equivocationProof.toJson(),
          'keyOwnerProof': keyOwnerProof.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i5.ForkVotingProof.codec.sizeHint(equivocationProof);
    size = size + _i4.MembershipProof.codec.sizeHint(keyOwnerProof);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i5.ForkVotingProof.codec.encodeTo(
      equivocationProof,
      output,
    );
    _i4.MembershipProof.codec.encodeTo(
      keyOwnerProof,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReportForkVoting &&
          other.equivocationProof == equivocationProof &&
          other.keyOwnerProof == keyOwnerProof;

  @override
  int get hashCode => Object.hash(
        equivocationProof,
        keyOwnerProof,
      );
}

/// Report fork voting equivocation. This method will verify the equivocation proof
/// and validate the given key ownership proof against the extracted offender.
/// If both are valid, the offence will be reported.
///
/// This extrinsic must be called unsigned and it is expected that only
/// block authors will call it (validated in `ValidateUnsigned`), as such
/// if the block author is defined it will be defined as the equivocation
/// reporter.
class ReportForkVotingUnsigned extends Call {
  const ReportForkVotingUnsigned({
    required this.equivocationProof,
    required this.keyOwnerProof,
  });

  factory ReportForkVotingUnsigned._decode(_i1.Input input) {
    return ReportForkVotingUnsigned(
      equivocationProof: _i5.ForkVotingProof.codec.decode(input),
      keyOwnerProof: _i4.MembershipProof.codec.decode(input),
    );
  }

  /// Box<ForkVotingProof<HeaderFor<T>, T::BeefyId,<T::AncestryHelper
  ///as AncestryHelper<HeaderFor<T>>>::Proof,>,>
  final _i5.ForkVotingProof equivocationProof;

  /// T::KeyOwnerProof
  final _i4.MembershipProof keyOwnerProof;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'report_fork_voting_unsigned': {
          'equivocationProof': equivocationProof.toJson(),
          'keyOwnerProof': keyOwnerProof.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i5.ForkVotingProof.codec.sizeHint(equivocationProof);
    size = size + _i4.MembershipProof.codec.sizeHint(keyOwnerProof);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    _i5.ForkVotingProof.codec.encodeTo(
      equivocationProof,
      output,
    );
    _i4.MembershipProof.codec.encodeTo(
      keyOwnerProof,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReportForkVotingUnsigned &&
          other.equivocationProof == equivocationProof &&
          other.keyOwnerProof == keyOwnerProof;

  @override
  int get hashCode => Object.hash(
        equivocationProof,
        keyOwnerProof,
      );
}

/// Report future block voting equivocation. This method will verify the equivocation proof
/// and validate the given key ownership proof against the extracted offender.
/// If both are valid, the offence will be reported.
class ReportFutureBlockVoting extends Call {
  const ReportFutureBlockVoting({
    required this.equivocationProof,
    required this.keyOwnerProof,
  });

  factory ReportFutureBlockVoting._decode(_i1.Input input) {
    return ReportFutureBlockVoting(
      equivocationProof: _i6.FutureBlockVotingProof.codec.decode(input),
      keyOwnerProof: _i4.MembershipProof.codec.decode(input),
    );
  }

  /// Box<FutureBlockVotingProof<BlockNumberFor<T>, T::BeefyId>>
  final _i6.FutureBlockVotingProof equivocationProof;

  /// T::KeyOwnerProof
  final _i4.MembershipProof keyOwnerProof;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'report_future_block_voting': {
          'equivocationProof': equivocationProof.toJson(),
          'keyOwnerProof': keyOwnerProof.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i6.FutureBlockVotingProof.codec.sizeHint(equivocationProof);
    size = size + _i4.MembershipProof.codec.sizeHint(keyOwnerProof);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      5,
      output,
    );
    _i6.FutureBlockVotingProof.codec.encodeTo(
      equivocationProof,
      output,
    );
    _i4.MembershipProof.codec.encodeTo(
      keyOwnerProof,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReportFutureBlockVoting &&
          other.equivocationProof == equivocationProof &&
          other.keyOwnerProof == keyOwnerProof;

  @override
  int get hashCode => Object.hash(
        equivocationProof,
        keyOwnerProof,
      );
}

/// Report future block voting equivocation. This method will verify the equivocation proof
/// and validate the given key ownership proof against the extracted offender.
/// If both are valid, the offence will be reported.
///
/// This extrinsic must be called unsigned and it is expected that only
/// block authors will call it (validated in `ValidateUnsigned`), as such
/// if the block author is defined it will be defined as the equivocation
/// reporter.
class ReportFutureBlockVotingUnsigned extends Call {
  const ReportFutureBlockVotingUnsigned({
    required this.equivocationProof,
    required this.keyOwnerProof,
  });

  factory ReportFutureBlockVotingUnsigned._decode(_i1.Input input) {
    return ReportFutureBlockVotingUnsigned(
      equivocationProof: _i6.FutureBlockVotingProof.codec.decode(input),
      keyOwnerProof: _i4.MembershipProof.codec.decode(input),
    );
  }

  /// Box<FutureBlockVotingProof<BlockNumberFor<T>, T::BeefyId>>
  final _i6.FutureBlockVotingProof equivocationProof;

  /// T::KeyOwnerProof
  final _i4.MembershipProof keyOwnerProof;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {
        'report_future_block_voting_unsigned': {
          'equivocationProof': equivocationProof.toJson(),
          'keyOwnerProof': keyOwnerProof.toJson(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i6.FutureBlockVotingProof.codec.sizeHint(equivocationProof);
    size = size + _i4.MembershipProof.codec.sizeHint(keyOwnerProof);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      6,
      output,
    );
    _i6.FutureBlockVotingProof.codec.encodeTo(
      equivocationProof,
      output,
    );
    _i4.MembershipProof.codec.encodeTo(
      keyOwnerProof,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReportFutureBlockVotingUnsigned &&
          other.equivocationProof == equivocationProof &&
          other.keyOwnerProof == keyOwnerProof;

  @override
  int get hashCode => Object.hash(
        equivocationProof,
        keyOwnerProof,
      );
}
