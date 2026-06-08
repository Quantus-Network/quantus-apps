import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/open_proposal_entry.dart';
import 'package:resonance_network_wallet/v2/components/proposal_list_tile.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/proposal_row.dart';

/// Renders a pending or indexed open proposal row.
class OpenProposalEntryRow extends StatelessWidget {
  final MultisigAccount msig;
  final OpenProposalEntry entry;

  const OpenProposalEntryRow({super.key, required this.msig, required this.entry});

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      PendingOpenProposalEntry(:final pending) => PendingProposalRow(
        pending: pending,
        onTap: () => showTransactionDetailSheet(context, pending, msig.accountId),
      ),
      IndexedOpenProposalEntry(:final proposal) => ProposalRow(
        proposal: proposal,
        myAccountId: msig.myMemberAccountId,
        onTap: () => showMultisigProposalDetailSheet(context, msig: msig, proposal: proposal),
      ),
    };
  }
}
