import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/approve/approve_proposal_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/proposal_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class MultisigProposalsSection extends ConsumerWidget {
  final MultisigAccount msig;
  const MultisigProposalsSection({super.key, required this.msig});

  void _openProposal(BuildContext context, MultisigProposal proposal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApproveProposalScreen(msig: msig, proposalId: proposal.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final openAsync = ref.watch(multisigOpenProposalsProvider(msig));
    final pastAsync = ref.watch(multisigPastProposalsProvider(msig));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(l10n.multisigOpenProposals, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 16),
        _buildList(context, l10n, openAsync, emptyText: l10n.multisigNoOpenProposals),
        const SizedBox(height: 32),
        Text(l10n.multisigPastProposals, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 16),
        _buildList(context, l10n, pastAsync, emptyText: l10n.multisigNoPastProposals),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<MultisigProposal>> async_, {
    required String emptyText,
  }) {
    final colors = context.colors;
    final text = context.themeText;
    return async_.when(
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Loader()),
      ),
      error: (e, _) =>
          Text(l10n.multisigLoadFailed(e.toString()), style: text.detail?.copyWith(color: colors.textError)),
      data: (items) {
        if (items.isEmpty) {
          return Text(emptyText, style: text.smallParagraph?.copyWith(color: colors.textTertiary));
        }
        return Column(
          children: List.generate(items.length, (i) {
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: ProposalRow(
                proposal: items[i],
                myAccountId: msig.myMemberAccountId,
                onTap: () => _openProposal(context, items[i]),
              ),
            );
          }),
        );
      },
    );
  }
}
