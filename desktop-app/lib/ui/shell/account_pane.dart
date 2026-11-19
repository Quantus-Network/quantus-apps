import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/in_progress_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The active account's panels: its balance; what of it is still under way
/// and, for a multisig, its open proposals, each only as tall as it needs;
/// then its activity. Its actions are in the top bar.
class AccountPane extends ConsumerWidget {
  const AccountPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return ref
        .watch(activeAccountProvider)
        .when(
          loading: () => const Center(child: Loader()),
          error: (_, _) => _message(context, l10n.accountsSheetFailedLoadActiveAccount),
          data: (active) => active == null ? _message(context, l10n.homeNoActiveAccount) : _content(ref, active),
        );
  }

  Widget _message(BuildContext context, String message) {
    return Center(
      child: Text(message, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
    );
  }

  Widget _content(WidgetRef ref, DisplayAccount active) {
    final account = active.account;
    final inProgress = ref.watch(activityViewProvider).value?.inProgress ?? const <TransactionEvent>[];
    final multisig = account is MultisigAccount ? account : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // What sits over Activity takes half the column at most, or a third
        // each when both do.
        final shares = (inProgress.isEmpty ? 0 : 1) + (multisig == null ? 0 : 1);
        final limit = shares == 0 ? 0.0 : constraints.maxHeight / (shares == 1 ? 2 : 3);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalanceCard(account: account),
            if (inProgress.isNotEmpty) ...[
              const SizedBox(height: Panel.gap),
              InProgressPanel(transactions: inProgress, maxHeight: limit),
            ],
            if (multisig != null) ...[
              const SizedBox(height: Panel.gap),
              OpenProposalsPanel(multisig: multisig, maxHeight: limit),
            ],
            const SizedBox(height: Panel.gap),
            const Expanded(child: ActivityPanel()),
          ],
        );
      },
    );
  }
}
