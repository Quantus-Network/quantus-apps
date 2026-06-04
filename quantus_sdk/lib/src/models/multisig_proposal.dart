import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';

/// On-chain lifecycle status of a multisig proposal.
///
/// Mirrors the indexer `MultisigProposalStatus` enum. Expiry is derived from
/// [MultisigProposal.expiryBlock] versus the current block and is therefore not
/// a stored status.
enum MultisigProposalStatus { active, approved, executed, cancelled, removed }

/// A multisig proposal as exposed by the indexer.
@immutable
class MultisigProposal {
  static final multisig_pallet.Constants _palletConstants = multisig_pallet.Constants();

  /// Indexer row id (stable, unique). Used for activity de-duplication.
  final String entityId;

  /// On-chain proposal nonce within the multisig.
  final int id;
  final String multisigAddress;
  final String proposer;
  final DateTime createdAt;

  /// Decoded pallet name (e.g. `Balances`). Empty when undecodable.
  final String pallet;

  /// Decoded call name (e.g. `transfer_allow_death`). Empty when undecodable.
  final String call;

  /// Raw encoded call bytes as hex.
  final String callRaw;

  /// Balances transfer recipient, or empty when not a transfer.
  final String recipient;

  /// Balances transfer amount in planck, or zero when not a transfer.
  final BigInt amount;
  final int expiryBlock;
  final List<String> approvals;
  final BigInt deposit;

  /// Non-refundable proposal fee (from pallet constants; not stored per row).
  final BigInt fee;
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
    required this.pallet,
    required this.call,
    required this.callRaw,
    required this.recipient,
    required this.amount,
    required this.expiryBlock,
    required this.approvals,
    required this.deposit,
    required this.fee,
    required this.status,
    required this.threshold,
    required this.signerCount,
    this.decodeError,
  });

  /// Maps an indexer `multisig_proposal` record to a [MultisigProposal].
  ///
  /// [msig] supplies threshold and signer count, which the proposal row does
  /// not carry.
  factory MultisigProposal.fromIndexerJson(Map<String, dynamic> record, {required MultisigAccount msig}) {
    final transferAmountRaw = record['transfer_amount'] ?? record['transferAmount'];
    return MultisigProposal(
      entityId: stringFromJson(record['id']),
      id: _intFromJson(record['proposal_id'] ?? record['proposalId']),
      multisigAddress: msig.accountId,
      proposer: nestedAccountId(record['proposer']),
      createdAt: dateTimeFromJson(record['created_at'] ?? record['createdAt']),
      pallet: _stringOrEmpty(record['pallet']),
      call: _stringOrEmpty(record['call']),
      callRaw: _stringOrEmpty(record['call_raw'] ?? record['callRaw']),
      recipient: nestedAccountId(record['transferTo'] ?? record['transfer_to']),
      amount: transferAmountRaw != null ? bigIntFromJson(transferAmountRaw) : BigInt.zero,
      expiryBlock: _intFromJson(record['expiry_block'] ?? record['expiryBlock']),
      approvals: _stringList(record['approvals']),
      deposit: bigIntFromJson(record['deposit']),
      fee: _palletConstants.proposalFee,
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
      _ => MultisigProposalStatus.active,
    };
  }

  int get approvalCount => approvals.length;
  bool didApprove(String accountId) => approvals.contains(accountId);

  /// Explorer route segment for `/multisig-proposals/:id`.
  ///
  /// Uses the indexer row id when present; otherwise `{multisigAddress}-{id}`.
  String get explorerProposalId =>
      entityId.isNotEmpty ? entityId : '$multisigAddress-$id';

  /// Whether the proposal is still awaiting action on-chain.
  bool get isOpen => status == MultisigProposalStatus.active || status == MultisigProposalStatus.approved;

  /// Whether the proposal has reached a final state.
  bool get isTerminal => !isOpen;

  /// Whether an open proposal has passed its expiry block.
  bool expired(int currentBlock) => isOpen && currentBlock >= expiryBlock;

  /// Whether this proposal should appear in the pinned "open" section.
  bool isActionable(int currentBlock) => isOpen && !expired(currentBlock);

  MultisigProposal copyWith({MultisigProposalStatus? status, List<String>? approvals}) {
    return MultisigProposal(
      entityId: entityId,
      id: id,
      multisigAddress: multisigAddress,
      proposer: proposer,
      createdAt: createdAt,
      pallet: pallet,
      call: call,
      callRaw: callRaw,
      recipient: recipient,
      amount: amount,
      expiryBlock: expiryBlock,
      approvals: approvals ?? this.approvals,
      deposit: deposit,
      fee: fee,
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
}
