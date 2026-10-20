import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/history_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_header_card.dart';
import 'package:quantus_desktop_wallet/ui/components/card_grid.dart';
import 'package:quantus_desktop_wallet/ui/components/copyable_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_desktop_wallet/ui/components/grouped_transaction_list.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = ref.watch(currentAccountProvider);
    final history = ref.watch(accountHistoryProvider);
    if (account == null || history == null) {
      return DesktopPage(title: l10n.accountTitle, child: const Skeleton(height: 200));
    }
    final checkphrase = ref.watch(checksumNameProvider(account.accountId)).value;

    return DesktopPage(
      title: account.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BalanceHeaderCard(
            label: l10n.dashboardTotalBalance,
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Flexible(
                    child: CopyableText(
                      value: account.accountId,
                      display: AddressFormattingService.formatAddress(account.accountId),
                      copiedMessage: l10n.commonCopied,
                    ),
                  ),
                  if (checkphrase != null && checkphrase.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(checkphrase, style: text.body.copyWith(color: colors.semanticLilac)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: CardGrid.gap),
          DesktopCard(
            child: GroupedTransactionList(
              history: history,
              accountId: account.accountId,
              onLoadMore: () => historyControllerFor(ref.read, account.accountId).fetchMore(),
            ),
          ),
        ],
      ),
    );
  }
}
