import 'package:quantus_sdk/src/models/account_event_cursor.dart';
import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';

/// What can happen to a multisig's proposal, in the order a proposal goes
/// through them, each with the indexer's table of it.
enum MultisigProposalActivityKind {
  created('multisig_proposal_created'),
  signed('multisig_signer_approved'),

  /// The signature that reached the threshold was given: recorded beside
  /// that signature, or beside the creation in a multisig of one approval.
  ready('multisig_proposal_ready'),
  executed('executed_multisig_proposal'),
  cancelled('cancelled_multisig_proposal'),
  removed('removed_multisig_proposal');

  const MultisigProposalActivityKind(this.table);

  final String table;
}

/// Where each kind of a multisig's proposal activity is read on from.
typedef MultisigProposalActivityCursor = Map<MultisigProposalActivityKind, AccountEventCursor>;

/// One thing that happened to a multisig's proposal, as the indexer recorded
/// it.
class MultisigProposalActivity {
  final MultisigProposalActivityKind kind;

  /// The indexer's id of this record, unique within its [kind].
  final String id;

  final DateTime timestamp;

  /// The proposal as it stands now, which may be further on than this record.
  final MultisigProposal proposal;

  /// The hash of the transaction the proposal was created in.
  final String? creationHash;

  /// Who did it: the proposer, the signer, whoever gave the signature that
  /// made it ready, and whoever executed, cancelled or removed it.
  final String actor;

  /// How many approvals the proposal had with this signature. Only of a
  /// signature and of becoming ready.
  final int? approvalsCount;

  /// Whether the proposed call went through. Only of an execution.
  final bool? succeeded;

  const MultisigProposalActivity({
    required this.kind,
    required this.id,
    required this.timestamp,
    required this.proposal,
    required this.creationHash,
    required this.actor,
    this.approvalsCount,
    this.succeeded,
  });

  /// Reads a row of [kind]'s table for a proposal of [msig]. Throws on a row
  /// that lacks what its kind always has.
  factory MultisigProposalActivity.fromIndexerJson(
    MultisigProposalActivityKind kind,
    Map<String, dynamic> row, {
    required MultisigAccount msig,
  }) {
    final proposalJson = jsonMapRequired(row['proposal'], 'proposal');
    final proposal = MultisigProposal.fromIndexerJson(proposalJson, msig: msig);
    final signer = jsonMapOrNull(row['extrinsic'])?['signer'];
    final actor = switch (kind) {
      MultisigProposalActivityKind.created => proposal.proposer,
      MultisigProposalActivityKind.signed => nestedAccountId(row['approver']),
      MultisigProposalActivityKind.ready || MultisigProposalActivityKind.executed => nestedAccountId(signer),
      MultisigProposalActivityKind.cancelled => nestedAccountId(row['cancelledBy']),
      MultisigProposalActivityKind.removed => nestedAccountId(row['removedBy']),
    };
    if (actor.isEmpty) throw FormatException('A ${kind.name} record does not say who did it: ${row['id']}');
    final counts = kind == MultisigProposalActivityKind.signed || kind == MultisigProposalActivityKind.ready;
    return MultisigProposalActivity(
      kind: kind,
      id: stringFromJson(row['id']),
      timestamp: dateTimeFromJson(row['timestamp']),
      proposal: proposal,
      creationHash: jsonMapOrNull(proposalJson['createdExtrinsic'])?['id'] as String?,
      actor: actor,
      approvalsCount: counts ? intFromJson(row['approvals_count']) : null,
      succeeded: kind == MultisigProposalActivityKind.executed ? row['result'] == 'Ok' : null,
    );
  }
}

/// What happened to a multisig's proposals since it was last read, oldest
/// first, and where its next read starts.
class MultisigProposalActivitySince {
  final List<MultisigProposalActivity> activity;

  /// For every kind: its last row read, or the cursor the read was asked
  /// with when there was none.
  final MultisigProposalActivityCursor cursor;

  const MultisigProposalActivitySince({required this.activity, required this.cursor});
}
