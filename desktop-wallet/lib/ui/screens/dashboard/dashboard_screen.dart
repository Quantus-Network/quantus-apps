import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/balance_providers.dart';
import 'package:quantus_desktop_wallet/providers/chart_providers.dart';
import 'package:quantus_desktop_wallet/providers/history_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/router.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_chart.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_header_card.dart';
import 'package:quantus_desktop_wallet/ui/components/card_grid.dart';
import 'package:quantus_desktop_wallet/ui/components/chart_range_selector.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_desktop_wallet/ui/components/empty_state.dart';
import 'package:quantus_desktop_wallet/ui/components/grouped_transaction_list.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = ref.watch(currentAccountProvider);
    final history = ref.watch(accountHistoryProvider);
    final balance = ref.watch(currentBalanceProvider).value;
    final chart = ref.watch(balanceChartProvider);
    final fresh = history != null && !history.isLoading && history.isEmpty && balance == BigInt.zero;

    return DesktopPage(
      title: l10n.dashboardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BalanceHeaderCard(label: l10n.dashboardTotalBalance),
          const SizedBox(height: CardGrid.gap),
          if (fresh)
            DesktopCard(
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: l10n.dashboardEmptyTitle,
                body: l10n.dashboardEmptyBody,
                actions: [
                  QuantusButton.simple(label: l10n.navReceive, width: 160, onTap: () => context.go(AppRoutes.receive)),
                  QuantusButton.simple(
                    label: l10n.navSwap,
                    variant: ButtonVariant.staged,
                    width: 160,
                    onTap: () => context.go(AppRoutes.swap),
                  ),
                ],
              ),
            )
          else
            CardGrid(
              children: [
                DesktopCard(
                  title: l10n.dashboardBalanceCard,
                  trailing: const ChartRangeSelector(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      chart.when(
                        loading: () => const Skeleton(height: 220),
                        error: (e, _) => SizedBox(
                          height: 220,
                          child: Center(
                            child: Text('$e', style: text.caption.copyWith(color: colors.semanticEmber)),
                          ),
                        ),
                        data: (points) => points.length < 2
                            ? SizedBox(
                                height: 220,
                                child: Center(
                                  child: Text(
                                    l10n.dashboardNoActivity,
                                    style: text.caption.copyWith(color: colors.textMuted),
                                  ),
                                ),
                              )
                            : BalanceChart(points: points),
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.dashboardChartApproximate, style: text.caption.copyWith(color: colors.textMuted2)),
                    ],
                  ),
                ),
                DesktopCard(
                  title: l10n.dashboardRecent,
                  trailing: QuantusButton.simple(
                    label: l10n.commonViewAll,
                    variant: ButtonVariant.underline,
                    width: null,
                    onTap: () => context.go(AppRoutes.account),
                  ),
                  child: history == null || account == null
                      ? const Skeleton(height: 200)
                      : GroupedTransactionList(history: history, accountId: account.accountId, limit: 5),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
