import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';

/// Blocks, payout and every owned address of one chain.
Future<void> showChainRewardsSheet(BuildContext context, ChainRewards rewards) =>
    BottomSheetContainer.show<void>(context, builder: (_) => _ChainRewardsSheet(rewards: rewards));

class _ChainRewardsSheet extends ConsumerWidget {
  final ChainRewards rewards;

  const _ChainRewardsSheet({required this.rewards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    const rowPadding = EdgeInsets.symmetric(vertical: 14);

    return BottomSheetContainer(
      key: const Key(E2EKeys.miningRewardsChainSheet),
      title: rewards.chain.displayName,
      trailing: QuantusIconButton.ghost(
        icon: Icons.close,
        onTap: () => Navigator.pop(context),
        size: IconButtonSize.small,
      ),
      child: Column(
        children: [
          DetailSummaryRow(
            label: l10n.miningRewardsSheetBlocksMined,
            value: fmt.formatInteger(rewards.blocksMined),
            labelStyle: text.body.copyWith(color: colors.textMuted),
            padding: rowPadding,
          ),
          const MenuDivider(),
          DetailSummaryRow(
            label: l10n.miningRewardsSheetReward,
            value: fmt.formatHundredths(rewards.rewardHundredths, addSymbol: true),
            labelStyle: text.body.copyWith(color: colors.textMuted),
            valueColor: colors.semanticSage,
            padding: rowPadding,
          ),
          for (final row in rewards.rows) ...[
            const MenuDivider(),
            DetailSummaryRow(
              label: AddressFormattingService.formatAddress(row.address),
              value: row.claimable ? fmt.formatHundredths(row.reward.rewardHundredths) : l10n.miningRewardsNotClaimable,
              labelStyle: text.dataAddress.copyWith(color: colors.textMuted),
              padding: rowPadding,
            ),
          ],
        ],
      ),
    );
  }
}
