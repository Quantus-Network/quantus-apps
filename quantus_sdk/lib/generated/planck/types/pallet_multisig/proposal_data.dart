// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../sp_core/crypto/account_id32.dart' as _i2;
import 'proposal_status.dart' as _i3;

class ProposalData {
  const ProposalData({
    required this.proposer,
    required this.call,
    required this.expiry,
    required this.approvals,
    required this.deposit,
    required this.status,
  });

  factory ProposalData.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// AccountId
  final _i2.AccountId32 proposer;

  /// BoundedCall
  final List<int> call;

  /// BlockNumber
  final int expiry;

  /// BoundedApprovals
  final List<_i2.AccountId32> approvals;

  /// Balance
  final BigInt deposit;

  /// ProposalStatus
  final _i3.ProposalStatus status;

  static const $ProposalDataCodec codec = $ProposalDataCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
    'proposer': proposer.toList(),
    'call': call,
    'expiry': expiry,
    'approvals': approvals.map((value) => value.toList()).toList(),
    'deposit': deposit,
    'status': status.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposalData &&
          _i5.listsEqual(other.proposer, proposer) &&
          _i5.listsEqual(other.call, call) &&
          other.expiry == expiry &&
          _i5.listsEqual(other.approvals, approvals) &&
          other.deposit == deposit &&
          other.status == status;

  @override
  int get hashCode => Object.hash(proposer, call, expiry, approvals, deposit, status);
}

class $ProposalDataCodec with _i1.Codec<ProposalData> {
  const $ProposalDataCodec();

  @override
  void encodeTo(ProposalData obj, _i1.Output output) {
    const _i1.U8ArrayCodec(32).encodeTo(obj.proposer, output);
    _i1.U8SequenceCodec.codec.encodeTo(obj.call, output);
    _i1.U32Codec.codec.encodeTo(obj.expiry, output);
    const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()).encodeTo(obj.approvals, output);
    _i1.U128Codec.codec.encodeTo(obj.deposit, output);
    _i3.ProposalStatus.codec.encodeTo(obj.status, output);
  }

  @override
  ProposalData decode(_i1.Input input) {
    return ProposalData(
      proposer: const _i1.U8ArrayCodec(32).decode(input),
      call: _i1.U8SequenceCodec.codec.decode(input),
      expiry: _i1.U32Codec.codec.decode(input),
      approvals: const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()).decode(input),
      deposit: _i1.U128Codec.codec.decode(input),
      status: _i3.ProposalStatus.codec.decode(input),
    );
  }

  @override
  int sizeHint(ProposalData obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.proposer);
    size = size + _i1.U8SequenceCodec.codec.sizeHint(obj.call);
    size = size + _i1.U32Codec.codec.sizeHint(obj.expiry);
    size = size + const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()).sizeHint(obj.approvals);
    size = size + _i1.U128Codec.codec.sizeHint(obj.deposit);
    size = size + _i3.ProposalStatus.codec.sizeHint(obj.status);
    return size;
  }
}
