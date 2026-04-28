import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/utils/url_utils.dart';
import 'package:resonance_network_wallet/v2/screens/activity/activity_screen.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/settings/testnet_rewards_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivitySection extends ConsumerStatefulWidget {
  final AsyncValue<CombinedTransactionsList> txAsync;
  final BaseAccount activeAccount;
  final Future<void> Function()? onRetry;

  const ActivitySection({super.key, required this.txAsync, required this.activeAccount, this.onRetry});

  @override
  ConsumerState<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends ConsumerState<ActivitySection> {
  bool _getStartedExpanded = true;

  @override
  Widget build(BuildContext context) {
    final formatTxAmount = ref.watch(txAmountDisplayProvider);
    final colors = context.colors;
    final text = context.themeText;

    return widget.txAsync.when(
      data: (data) {
        final txService = ref.read(transactionServiceProvider);
        final all = txService.combineAndDeduplicateTransactions(
          pendingCancellationIds: data.pendingCancellationIds,
          pendingTransactions: data.pendingTransactions,
          scheduledReversibleTransfers: data.scheduledReversibleTransfers,
          otherTransfers: data.otherTransfers,
        );
        final recentTransactions = all.take(5).toList();

        if (all.isEmpty) {
          return Column(
            children: [
              const SizedBox(height: 40),
              _header(colors, text, context),
              _emptyState(text, colors),
              const SizedBox(height: 40),
              _getStartedSection(text, colors),
            ],
          );
        }

        return Column(
          children: [
            const SizedBox(height: 40),
            _header(colors, text, context),
            const SizedBox(height: 28),

            ...recentTransactions.mapIndexed((index, tx) {
              final data = TxItemData.from(tx, widget.activeAccount.accountId, colors);
              final isLastItem = index == recentTransactions.length - 1;

              return buildTxItem(
                tx,
                data,
                colors,
                text,
                formattedAmount: formatTxAmount(data.amount, isSend: data.isSend).primaryAmount,
                isLastItem: isLastItem,
                onTap: () {
                  showTransactionDetailSheet(context, tx, widget.activeAccount.accountId);
                },
              );
            }),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(colors, text, context),
            const SizedBox(height: 24),
            for (var i = 0; i < 3; i++) ...[
              const Skeleton.txItem(),
              if (i < 2) Divider(color: colors.txItemSeparator, height: 24),
            ],
          ],
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text('Error loading transactions', style: text.detail?.copyWith(color: colors.textError)),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.invalidate(activeAccountTransactionsProvider);
                widget.onRetry?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Retry',
                  style: text.smallParagraph?.copyWith(color: colors.textPrimary, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppTextTheme text, AppColorsV2 colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('No Transactions Yet', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text('Your activity will appear here', style: text.detail?.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _getStartedSection(AppTextTheme text, AppColorsV2 colors) {
    const links = [
      ('Get Testnet Tokens', AppConstants.faucetUrl),
      ('Community', AppConstants.communityUrl),
      // ('Tech Support', AppConstants.techSupportUrl),
    ];

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _getStartedExpanded = !_getStartedExpanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Get Started', style: text.smallTitle),
              Icon(
                _getStartedExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: colors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < links.length; i++) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => links[i].$2 == AppConstants.faucetUrl
                          ? launchXPost(links[i].$2)
                          : launchUrl(Uri.parse(links[i].$2)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(links[i].$1, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                          Icon(Icons.arrow_outward, color: colors.textPrimary, size: 20),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: colors.separator, height: 0),
                    ),
                  ],
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const TestnetRewardsScreen())),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Testnet Rewards', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                        Icon(Icons.chevron_right, color: colors.textPrimary, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _getStartedExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _header(AppColorsV2 colors, AppTextTheme text, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Activity', style: text.smallTitle),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen())),
          child: Text(
            'View All',
            style: text.smallTitle?.copyWith(
              color: colors.textMuted,
              decoration: TextDecoration.underline,
              decorationColor: colors.textMuted,
              decorationStyle: TextDecorationStyle.dotted,
              decorationThickness: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
