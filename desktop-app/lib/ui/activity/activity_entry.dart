import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The row [tx] makes in the open account's lists: wallet_core's words for
/// it, its amount formatted, the wallet's own account on the other side by
/// its badge and name, open when it is the one the panel at the right shows.
/// A click opens it there; a multisig's past proposal opens as a proposal.
class ActivityEntry extends ConsumerWidget {
  const ActivityEntry({super.key, required this.tx, required this.form, this.hasFocus = true});

  final TransactionEvent tx;
  final ActivityRowForm form;

  /// Whether the keys are in the panel the row is in.
  final bool hasFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final formatting = ref.watch(numberFormattingServiceProvider);
    final account = ref.watch(activeAccountProvider).value?.account;
    if (account == null) throw StateError('An activity row was drawn with no open account.');
    final row = activityRowOf(tx, accountId: account.accountId, l10n: l10n, isPrivate: isEncryptedAccount(account));
    final own = ref.watch(ownAccountsByAddressProvider);
    final opened = ref.watch(openedActivityViewProvider);

    return ActivityRowView(
      id: tx.id,
      row: row,
      amountText: l10n.commonAmountBalance(formatting.formatBalance(row.amount), AppConstants.tokenSymbol),
      isAmountHidden: ref.watch(isBalanceHiddenProvider),
      form: form,
      l10n: l10n,
      ownCounterparty: switch (row.counterparty) {
        ActivityAccount(:final address) || ActivityMultisig(:final address) => own[address],
        ActivityUnnamedCounterparty() => null,
      },
      isSelected: opened?.id == tx.id,
      hasFocus: hasFocus,
      // A multisig's past proposal opens as the proposal it was.
      onTap: () => ref.read(openedActivityProvider.notifier).open(switch (tx) {
        MultisigProposalEvent(:final proposal) => OpenedProposal(proposal),
        _ => OpenedTransaction(tx),
      }),
    );
  }
}
