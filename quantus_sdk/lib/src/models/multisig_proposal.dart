import 'package:flutter/foundation.dart';

enum MultisigProposalStatus { active, approved, executed, cancelled, expired }

@immutable
class MultisigProposal {
  final int id;
  final String multisigAddress;
  final String proposer;
  final BigInt amount;
  final String recipient;
  final int expiryBlock;
  final DateTime expiryAt;
  final List<String> approvals;
  final BigInt deposit;
  final BigInt fee;
  final MultisigProposalStatus status;
  final int threshold;
  final int signerCount;

  const MultisigProposal({
    required this.id,
    required this.multisigAddress,
    required this.proposer,
    required this.amount,
    required this.recipient,
    required this.expiryBlock,
    required this.expiryAt,
    required this.approvals,
    required this.deposit,
    required this.fee,
    required this.status,
    required this.threshold,
    required this.signerCount,
  });

  int get approvalCount => approvals.length;
  bool didApprove(String accountId) => approvals.contains(accountId);
  bool get isOpen => status == MultisigProposalStatus.active || status == MultisigProposalStatus.approved;
}
