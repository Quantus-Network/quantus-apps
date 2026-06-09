// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../sp_core/crypto/account_id32.dart' as _i3;
import '../../sp_runtime/dispatch_error.dart' as _i4;

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

  MultisigCreated multisigCreated({
    required _i3.AccountId32 creator,
    required _i3.AccountId32 multisigAddress,
    required List<_i3.AccountId32> signers,
    required int threshold,
    required BigInt nonce,
  }) {
    return MultisigCreated(
      creator: creator,
      multisigAddress: multisigAddress,
      signers: signers,
      threshold: threshold,
      nonce: nonce,
    );
  }

  ProposalCreated proposalCreated({
    required _i3.AccountId32 multisigAddress,
    required _i3.AccountId32 proposer,
    required int proposalId,
  }) {
    return ProposalCreated(multisigAddress: multisigAddress, proposer: proposer, proposalId: proposalId);
  }

  SignerApproved signerApproved({
    required _i3.AccountId32 multisigAddress,
    required _i3.AccountId32 approver,
    required int proposalId,
    required int approvalsCount,
  }) {
    return SignerApproved(
      multisigAddress: multisigAddress,
      approver: approver,
      proposalId: proposalId,
      approvalsCount: approvalsCount,
    );
  }

  ProposalReadyToExecute proposalReadyToExecute({
    required _i3.AccountId32 multisigAddress,
    required int proposalId,
    required int approvalsCount,
  }) {
    return ProposalReadyToExecute(
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      approvalsCount: approvalsCount,
    );
  }

  ProposalExecuted proposalExecuted({
    required _i3.AccountId32 multisigAddress,
    required int proposalId,
    required _i3.AccountId32 proposer,
    required List<int> call,
    required List<_i3.AccountId32> approvers,
    required _i1.Result<dynamic, _i4.DispatchError> result,
  }) {
    return ProposalExecuted(
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      proposer: proposer,
      call: call,
      approvers: approvers,
      result: result,
    );
  }

  ProposalCancelled proposalCancelled({
    required _i3.AccountId32 multisigAddress,
    required _i3.AccountId32 proposer,
    required int proposalId,
  }) {
    return ProposalCancelled(multisigAddress: multisigAddress, proposer: proposer, proposalId: proposalId);
  }

  ProposalRemoved proposalRemoved({
    required _i3.AccountId32 multisigAddress,
    required int proposalId,
    required _i3.AccountId32 proposer,
    required _i3.AccountId32 removedBy,
  }) {
    return ProposalRemoved(
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      proposer: proposer,
      removedBy: removedBy,
    );
  }

  DepositsClaimed depositsClaimed({
    required _i3.AccountId32 multisigAddress,
    required _i3.AccountId32 claimer,
    required BigInt totalReturned,
    required int proposalsRemoved,
  }) {
    return DepositsClaimed(
      multisigAddress: multisigAddress,
      claimer: claimer,
      totalReturned: totalReturned,
      proposalsRemoved: proposalsRemoved,
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
        return MultisigCreated._decode(input);
      case 1:
        return ProposalCreated._decode(input);
      case 2:
        return SignerApproved._decode(input);
      case 3:
        return ProposalReadyToExecute._decode(input);
      case 4:
        return ProposalExecuted._decode(input);
      case 5:
        return ProposalCancelled._decode(input);
      case 6:
        return ProposalRemoved._decode(input);
      case 7:
        return DepositsClaimed._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Event value, _i1.Output output) {
    switch (value.runtimeType) {
      case MultisigCreated:
        (value as MultisigCreated).encodeTo(output);
        break;
      case ProposalCreated:
        (value as ProposalCreated).encodeTo(output);
        break;
      case SignerApproved:
        (value as SignerApproved).encodeTo(output);
        break;
      case ProposalReadyToExecute:
        (value as ProposalReadyToExecute).encodeTo(output);
        break;
      case ProposalExecuted:
        (value as ProposalExecuted).encodeTo(output);
        break;
      case ProposalCancelled:
        (value as ProposalCancelled).encodeTo(output);
        break;
      case ProposalRemoved:
        (value as ProposalRemoved).encodeTo(output);
        break;
      case DepositsClaimed:
        (value as DepositsClaimed).encodeTo(output);
        break;
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case MultisigCreated:
        return (value as MultisigCreated)._sizeHint();
      case ProposalCreated:
        return (value as ProposalCreated)._sizeHint();
      case SignerApproved:
        return (value as SignerApproved)._sizeHint();
      case ProposalReadyToExecute:
        return (value as ProposalReadyToExecute)._sizeHint();
      case ProposalExecuted:
        return (value as ProposalExecuted)._sizeHint();
      case ProposalCancelled:
        return (value as ProposalCancelled)._sizeHint();
      case ProposalRemoved:
        return (value as ProposalRemoved)._sizeHint();
      case DepositsClaimed:
        return (value as DepositsClaimed)._sizeHint();
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A new multisig account was created
/// [creator, multisig_address, signers, threshold, nonce]
class MultisigCreated extends Event {
  const MultisigCreated({
    required this.creator,
    required this.multisigAddress,
    required this.signers,
    required this.threshold,
    required this.nonce,
  });

  factory MultisigCreated._decode(_i1.Input input) {
    return MultisigCreated(
      creator: const _i1.U8ArrayCodec(32).decode(input),
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      signers: const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).decode(input),
      threshold: _i1.U32Codec.codec.decode(input),
      nonce: _i1.U64Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 creator;

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// Vec<T::AccountId>
  final List<_i3.AccountId32> signers;

  /// u32
  final int threshold;

  /// u64
  final BigInt nonce;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'MultisigCreated': {
      'creator': creator.toList(),
      'multisigAddress': multisigAddress.toList(),
      'signers': signers.map((value) => value.toList()).toList(),
      'threshold': threshold,
      'nonce': nonce,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(creator);
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).sizeHint(signers);
    size = size + _i1.U32Codec.codec.sizeHint(threshold);
    size = size + _i1.U64Codec.codec.sizeHint(nonce);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    const _i1.U8ArrayCodec(32).encodeTo(creator, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).encodeTo(signers, output);
    _i1.U32Codec.codec.encodeTo(threshold, output);
    _i1.U64Codec.codec.encodeTo(nonce, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultisigCreated &&
          _i5.listsEqual(other.creator, creator) &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          _i5.listsEqual(other.signers, signers) &&
          other.threshold == threshold &&
          other.nonce == nonce;

  @override
  int get hashCode => Object.hash(creator, multisigAddress, signers, threshold, nonce);
}

/// A proposal has been created
class ProposalCreated extends Event {
  const ProposalCreated({required this.multisigAddress, required this.proposer, required this.proposalId});

  factory ProposalCreated._decode(_i1.Input input) {
    return ProposalCreated(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposer: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// T::AccountId
  final _i3.AccountId32 proposer;

  /// u32
  final int proposalId;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ProposalCreated': {
      'multisigAddress': multisigAddress.toList(),
      'proposer': proposer.toList(),
      'proposalId': proposalId,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + const _i3.AccountId32Codec().sizeHint(proposer);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    const _i1.U8ArrayCodec(32).encodeTo(proposer, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposalCreated &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          _i5.listsEqual(other.proposer, proposer) &&
          other.proposalId == proposalId;

  @override
  int get hashCode => Object.hash(multisigAddress, proposer, proposalId);
}

/// A signer has approved a proposal (does not imply threshold reached)
class SignerApproved extends Event {
  const SignerApproved({
    required this.multisigAddress,
    required this.approver,
    required this.proposalId,
    required this.approvalsCount,
  });

  factory SignerApproved._decode(_i1.Input input) {
    return SignerApproved(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      approver: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
      approvalsCount: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// T::AccountId
  final _i3.AccountId32 approver;

  /// u32
  final int proposalId;

  /// u32
  final int approvalsCount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'SignerApproved': {
      'multisigAddress': multisigAddress.toList(),
      'approver': approver.toList(),
      'proposalId': proposalId,
      'approvalsCount': approvalsCount,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + const _i3.AccountId32Codec().sizeHint(approver);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    size = size + _i1.U32Codec.codec.sizeHint(approvalsCount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    const _i1.U8ArrayCodec(32).encodeTo(approver, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
    _i1.U32Codec.codec.encodeTo(approvalsCount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignerApproved &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          _i5.listsEqual(other.approver, approver) &&
          other.proposalId == proposalId &&
          other.approvalsCount == approvalsCount;

  @override
  int get hashCode => Object.hash(multisigAddress, approver, proposalId, approvalsCount);
}

/// A proposal has reached threshold and is ready to execute
class ProposalReadyToExecute extends Event {
  const ProposalReadyToExecute({required this.multisigAddress, required this.proposalId, required this.approvalsCount});

  factory ProposalReadyToExecute._decode(_i1.Input input) {
    return ProposalReadyToExecute(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
      approvalsCount: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// u32
  final int proposalId;

  /// u32
  final int approvalsCount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ProposalReadyToExecute': {
      'multisigAddress': multisigAddress.toList(),
      'proposalId': proposalId,
      'approvalsCount': approvalsCount,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    size = size + _i1.U32Codec.codec.sizeHint(approvalsCount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
    _i1.U32Codec.codec.encodeTo(approvalsCount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposalReadyToExecute &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          other.proposalId == proposalId &&
          other.approvalsCount == approvalsCount;

  @override
  int get hashCode => Object.hash(multisigAddress, proposalId, approvalsCount);
}

/// A proposal has been executed
/// Contains all data needed for indexing by SubSquid
class ProposalExecuted extends Event {
  const ProposalExecuted({
    required this.multisigAddress,
    required this.proposalId,
    required this.proposer,
    required this.call,
    required this.approvers,
    required this.result,
  });

  factory ProposalExecuted._decode(_i1.Input input) {
    return ProposalExecuted(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
      proposer: const _i1.U8ArrayCodec(32).decode(input),
      call: _i1.U8SequenceCodec.codec.decode(input),
      approvers: const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).decode(input),
      result: const _i1.ResultCodec<dynamic, _i4.DispatchError>(
        _i1.NullCodec.codec,
        _i4.DispatchError.codec,
      ).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// u32
  final int proposalId;

  /// T::AccountId
  final _i3.AccountId32 proposer;

  /// Vec<u8>
  final List<int> call;

  /// Vec<T::AccountId>
  final List<_i3.AccountId32> approvers;

  /// DispatchResult
  final _i1.Result<dynamic, _i4.DispatchError> result;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ProposalExecuted': {
      'multisigAddress': multisigAddress.toList(),
      'proposalId': proposalId,
      'proposer': proposer.toList(),
      'call': call,
      'approvers': approvers.map((value) => value.toList()).toList(),
      'result': result.toJson(),
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    size = size + const _i3.AccountId32Codec().sizeHint(proposer);
    size = size + _i1.U8SequenceCodec.codec.sizeHint(call);
    size = size + const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).sizeHint(approvers);
    size =
        size +
        const _i1.ResultCodec<dynamic, _i4.DispatchError>(
          _i1.NullCodec.codec,
          _i4.DispatchError.codec,
        ).sizeHint(result);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(4, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
    const _i1.U8ArrayCodec(32).encodeTo(proposer, output);
    _i1.U8SequenceCodec.codec.encodeTo(call, output);
    const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).encodeTo(approvers, output);
    const _i1.ResultCodec<dynamic, _i4.DispatchError>(
      _i1.NullCodec.codec,
      _i4.DispatchError.codec,
    ).encodeTo(result, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposalExecuted &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          other.proposalId == proposalId &&
          _i5.listsEqual(other.proposer, proposer) &&
          _i5.listsEqual(other.call, call) &&
          _i5.listsEqual(other.approvers, approvers) &&
          other.result == result;

  @override
  int get hashCode => Object.hash(multisigAddress, proposalId, proposer, call, approvers, result);
}

/// A proposal has been cancelled by the proposer
class ProposalCancelled extends Event {
  const ProposalCancelled({required this.multisigAddress, required this.proposer, required this.proposalId});

  factory ProposalCancelled._decode(_i1.Input input) {
    return ProposalCancelled(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposer: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// T::AccountId
  final _i3.AccountId32 proposer;

  /// u32
  final int proposalId;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ProposalCancelled': {
      'multisigAddress': multisigAddress.toList(),
      'proposer': proposer.toList(),
      'proposalId': proposalId,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + const _i3.AccountId32Codec().sizeHint(proposer);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(5, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    const _i1.U8ArrayCodec(32).encodeTo(proposer, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposalCancelled &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          _i5.listsEqual(other.proposer, proposer) &&
          other.proposalId == proposalId;

  @override
  int get hashCode => Object.hash(multisigAddress, proposer, proposalId);
}

/// Expired proposal was removed from storage
class ProposalRemoved extends Event {
  const ProposalRemoved({
    required this.multisigAddress,
    required this.proposalId,
    required this.proposer,
    required this.removedBy,
  });

  factory ProposalRemoved._decode(_i1.Input input) {
    return ProposalRemoved(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
      proposer: const _i1.U8ArrayCodec(32).decode(input),
      removedBy: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// u32
  final int proposalId;

  /// T::AccountId
  final _i3.AccountId32 proposer;

  /// T::AccountId
  final _i3.AccountId32 removedBy;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ProposalRemoved': {
      'multisigAddress': multisigAddress.toList(),
      'proposalId': proposalId,
      'proposer': proposer.toList(),
      'removedBy': removedBy.toList(),
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    size = size + const _i3.AccountId32Codec().sizeHint(proposer);
    size = size + const _i3.AccountId32Codec().sizeHint(removedBy);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(6, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
    const _i1.U8ArrayCodec(32).encodeTo(proposer, output);
    const _i1.U8ArrayCodec(32).encodeTo(removedBy, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposalRemoved &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          other.proposalId == proposalId &&
          _i5.listsEqual(other.proposer, proposer) &&
          _i5.listsEqual(other.removedBy, removedBy);

  @override
  int get hashCode => Object.hash(multisigAddress, proposalId, proposer, removedBy);
}

/// Batch deposits claimed
class DepositsClaimed extends Event {
  const DepositsClaimed({
    required this.multisigAddress,
    required this.claimer,
    required this.totalReturned,
    required this.proposalsRemoved,
  });

  factory DepositsClaimed._decode(_i1.Input input) {
    return DepositsClaimed(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      claimer: const _i1.U8ArrayCodec(32).decode(input),
      totalReturned: _i1.U128Codec.codec.decode(input),
      proposalsRemoved: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// T::AccountId
  final _i3.AccountId32 claimer;

  /// BalanceOf<T>
  final BigInt totalReturned;

  /// u32
  final int proposalsRemoved;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'DepositsClaimed': {
      'multisigAddress': multisigAddress.toList(),
      'claimer': claimer.toList(),
      'totalReturned': totalReturned,
      'proposalsRemoved': proposalsRemoved,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + const _i3.AccountId32Codec().sizeHint(claimer);
    size = size + _i1.U128Codec.codec.sizeHint(totalReturned);
    size = size + _i1.U32Codec.codec.sizeHint(proposalsRemoved);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(7, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    const _i1.U8ArrayCodec(32).encodeTo(claimer, output);
    _i1.U128Codec.codec.encodeTo(totalReturned, output);
    _i1.U32Codec.codec.encodeTo(proposalsRemoved, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepositsClaimed &&
          _i5.listsEqual(other.multisigAddress, multisigAddress) &&
          _i5.listsEqual(other.claimer, claimer) &&
          other.totalReturned == totalReturned &&
          other.proposalsRemoved == proposalsRemoved;

  @override
  int get hashCode => Object.hash(multisigAddress, claimer, totalReturned, proposalsRemoved);
}
