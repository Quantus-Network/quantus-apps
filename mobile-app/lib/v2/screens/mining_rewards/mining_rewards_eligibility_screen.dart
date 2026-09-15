import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_claim_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

/// Blocks one wallet mined on each testnet and what they pay out. The claim
/// opens once every chain has answered and at least one of them pays.
class MiningRewardsEligibilityScreen extends ConsumerWidget {
  final int walletIndex;

  const MiningRewardsEligibilityScreen({super.key, required this.walletIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final checks = [for (final chain in TestnetChain.values) (walletIndex: walletIndex, chain: chain)];
    final results = [for (final check in checks) ref.watch(chainEligibilityProvider(check))];
    final loaded = [for (final result in results) ?result.value];
    final allLoaded = loaded.length == results.length;
    final canClaim = allLoaded && loaded.any((r) => r.isEligible);
    final totalHundredths = loaded.fold(0, (sum, r) => sum + r.rewardHundredths);

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsEligibilityScreen),
      appBar: V2AppBar(title: l10n.miningRewardsEligibilityTitle(walletDisplayName(ref, l10n, walletIndex))),
      mainContent: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
            child: Column(
              children: [
                for (final (i, check) in checks.indexed) ...[
                  if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: MenuDivider()),
                  _ChainRow(check: check, result: results[i], l10n: l10n),
                ],
                if (allLoaded) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: MenuDivider()),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.miningRewardsTotal,
                          style: text.bodyEmphasis.copyWith(color: colors.textContent),
                        ),
                      ),
                      _RewardText(
                        hundredths: totalHundredths,
                        style: text.bodyEmphasis.copyWith(color: colors.semanticSage),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (allLoaded && !canClaim) ...[
            const SizedBox(height: 16),
            Text(l10n.miningRewardsNone, style: text.caption.copyWith(color: colors.textMuted)),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.miningRewardsClaimButton),
          label: l10n.miningRewardsClaim,
          isDisabled: !canClaim,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MiningRewardsClaimScreen(walletIndex: walletIndex, eligibilities: loaded),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChainRow extends ConsumerWidget {
  final ChainCheck check;
  final AsyncValue<ChainRewards> result;
  final AppLocalizations l10n;

  const _ChainRow({required this.check, required this.result, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Row(
      children: [
        Expanded(
          child: Text(check.chain.displayName, style: text.body.copyWith(color: colors.textContent)),
        ),
        result.when(
          skipLoadingOnRefresh: false,
          loading: () => const Loader(),
          error: (_, _) => GestureDetector(
            onTap: () => ref.invalidate(chainEligibilityProvider(check)),
            child: Text(l10n.miningRewardsCheckFailed, style: text.caption.copyWith(color: colors.semanticEmber)),
          ),
          data: (rewards) => Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.miningRewardsBlocksMined(rewards.blocksMined),
                style: rewards.isEligible
                    ? text.bodyEmphasis.copyWith(color: colors.textContent)
                    : text.body.copyWith(color: colors.textMuted),
              ),
              if (rewards.isEligible) ...[
                const SizedBox(height: 4),
                _RewardText(
                  hundredths: rewards.rewardHundredths,
                  style: text.caption.copyWith(color: colors.semanticSage),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardText extends ConsumerWidget {
  final int hundredths;
  final TextStyle style;

  const _RewardText({required this.hundredths, required this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    return Text(fmt.formatBalance(hundredthsToTokens(hundredths), maxDecimals: 2, addSymbol: true), style: style);
  }
}
