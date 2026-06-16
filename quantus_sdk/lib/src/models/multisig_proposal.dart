import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart';
import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';

/// On-chain lifecycle status of a multisig proposal.
///
/// Mirrors the indexer `MultisigProposalStatus` enum. Expiry is derived from
/// [MultisigProposal.expiryBlock] versus the current block and is therefore not
/// a stored status.
enum MultisigProposalStatus { active, approved, executed, cancelled, removed, unknown }

/// A multisig proposal as exposed by the indexer.
@immutable
class MultisigProposal {
  /// Indexer row id (stable, unique). Used for activity de-duplication.
  final String entityId;

  /// On-chain proposal nonce within the multisig.
  final int id;
  final String multisigAddress;
  final String proposer;
  final DateTime createdAt;

  /// Last on-chain update (approval, execution, cancellation, etc.).
  final DateTime updatedAt;

  /// Decoded pallet name (e.g. `Balances`). Empty when undecodable.
  final String pallet;

  /// Decoded call name (e.g. `transfer_allow_death`). Empty when undecodable.
  final String call;

  /// Balances transfer recipient, or empty when not a transfer.
  final String recipient;

  /// Balances transfer amount in planck, or zero when not a transfer.
  final BigInt amount;
  final int expiryBlock;
  final List<String> approvals;
  final BigInt deposit;

  /// Non-refundable burned pallet fee from the indexer, when indexed.
  final BigInt? burnedPalletFee;

  /// Extrinsic network fee paid when this proposal was created, when indexed.
  final BigInt? networkFee;
  final MultisigProposalStatus status;
  final String? decodeError;

  /// Approval threshold of the owning multisig (injected at mapping time).
  final int threshold;

  /// Signer count of the owning multisig (injected at mapping time).
  final int signerCount;

  const MultisigProposal({
    required this.entityId,
    required this.id,
    required this.multisigAddress,
    required this.proposer,
    required this.createdAt,
    required this.updatedAt,
    required this.pallet,
    required this.call,
    required this.recipient,
    required this.amount,
    required this.expiryBlock,
    required this.approvals,
    required this.deposit,
    this.burnedPalletFee,
    this.networkFee,
    required this.status,
    required this.threshold,
    required this.signerCount,
    this.decodeError,
  });

  /// Maps an indexer `multisig_proposal` record to a [MultisigProposal].
  ///
  /// [msig] supplies threshold and signer count, which the proposal row does
  /// not carry. [burnedPalletFeeOverride] fills in when the nested row lacks
  /// `burned_pallet_fee` but the parent account event carries it.
  factory MultisigProposal.fromIndexerJson(
    Map<String, dynamic> record, {
    required MultisigAccount msig,
    BigInt? burnedPalletFeeOverride,
  }) {
    final transferAmountRaw = record['transfer_amount'] ?? record['transferAmount'];
    final burnedRaw = record['burned_pallet_fee'] ?? record['burnedPalletFee'];
    return MultisigProposal(
      entityId: stringFromJson(record['id']),
      id: _intFromJson(record['proposal_id'] ?? record['proposalId']),
      multisigAddress: msig.accountId,
      proposer: nestedAccountId(record['proposer']),
      createdAt: dateTimeFromJson(record['created_at']),
      // The indexer omits updated_at on rows that have never been updated.
      updatedAt: dateTimeFromJson(record['updated_at'] ?? record['created_at']),
      pallet: _stringOrEmpty(record['pallet']),
      call: _stringOrEmpty(record['call']),
      recipient: nestedAccountId(record['transferTo'] ?? record['transfer_to']),
      amount: transferAmountRaw != null ? bigIntFromJson(transferAmountRaw) : BigInt.zero,
      expiryBlock: _intFromJson(record['expiry_block'] ?? record['expiryBlock']),
      approvals: _stringList(record['approvals']),
      deposit: bigIntFromJson(record['deposit']),
      burnedPalletFee: burnedRaw != null ? bigIntFromJson(burnedRaw) : burnedPalletFeeOverride,
      networkFee: _optionalBigInt(record['creation_network_fee'] ?? record['creationNetworkFee']),
      status: parseStatus(record['status']),
      threshold: msig.threshold,
      signerCount: msig.signers.length,
      decodeError: (record['decode_error'] ?? record['decodeError']) as String?,
    );
  }

  /// Parses a (possibly upper-cased) indexer status string.
  static MultisigProposalStatus parseStatus(dynamic raw) {
    final value = raw?.toString().toLowerCase();
    return switch (value) {
      'active' => MultisigProposalStatus.active,
      'approved' => MultisigProposalStatus.approved,
      'executed' => MultisigProposalStatus.executed,
      'cancelled' => MultisigProposalStatus.cancelled,
      'removed' => MultisigProposalStatus.removed,
      _ => _unknownStatus(raw),
    };
  }

  static MultisigProposalStatus _unknownStatus(dynamic raw) {
    developer.log('Unknown multisig proposal status: $raw', name: 'MultisigProposal');
    return MultisigProposalStatus.unknown;
  }

  /// Non-refundable burned fee for creating a proposal, scaled by [signerCount].
  ///
  /// Formula: `proposalFee + (proposalFee * signerCount * signerStepFactor / 1_000_000)`.
  static BigInt proposalCreationFeeFor(int signerCount) {
    final palletConstants = Constants();

    final base = palletConstants.proposalFee;
    final step = palletConstants.signerStepFactor;
    final extra = base * BigInt.from(signerCount) * BigInt.from(step) ~/ BigInt.from(1000000);
    return base + extra;
  }

  int get approvalCount => approvals.length;
  bool didApprove(String accountId) => approvals.contains(accountId);

  /// Non-refundable burned pallet fee; prefers indexer data, else local estimate.
  BigInt get palletFee => burnedPalletFee ?? proposalCreationFeeFor(signerCount);

  /// Explorer route segment for `/multisig-proposals/:id`.
  ///
  /// Uses the indexer row id when present; otherwise `{multisigAddress}-{id}`.
  String get explorerProposalId => entityId.isNotEmpty ? entityId : '$multisigAddress-$id';

  /// Whether the proposal is still awaiting action on-chain.
  bool get isOpen => status == MultisigProposalStatus.active || status == MultisigProposalStatus.approved;

  /// Whether the proposal has reached a final state.
  bool get isTerminal => !isOpen;

  /// Whether an open proposal has passed its expiry block.
  bool expired(int currentBlock) => isOpen && currentBlock >= expiryBlock;

  /// Whether this proposal should appear in the pinned "open" section.
  bool isActionable(int currentBlock) => isOpen && !expired(currentBlock);

  /// Whether threshold is met and the proposal awaits execution.
  bool get isReadyToExecute => status == MultisigProposalStatus.approved;

  MultisigProposal copyWith({MultisigProposalStatus? status, List<String>? approvals, BigInt? burnedPalletFee}) {
    return MultisigProposal(
      entityId: entityId,
      id: id,
      multisigAddress: multisigAddress,
      proposer: proposer,
      createdAt: createdAt,
      updatedAt: updatedAt,
      pallet: pallet,
      call: call,
      recipient: recipient,
      amount: amount,
      expiryBlock: expiryBlock,
      approvals: approvals ?? this.approvals,
      deposit: deposit,
      burnedPalletFee: burnedPalletFee ?? this.burnedPalletFee,
      networkFee: networkFee,
      status: status ?? this.status,
      threshold: threshold,
      signerCount: signerCount,
      decodeError: decodeError,
    );
  }

  static int _intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.parse(value);
    throw FormatException('Cannot parse int from ${value.runtimeType}: $value');
  }

  static String _stringOrEmpty(dynamic value) => value is String ? value : '';

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return <String>[];
  }

  static BigInt? _optionalBigInt(dynamic value) {
    if (value == null) return null;
    return bigIntFromJson(value);
  }
}
