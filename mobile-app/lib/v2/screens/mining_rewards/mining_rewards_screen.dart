import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/debug_mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

/// Entry to the testnet mining rewards claim: every software wallet with what
/// it has already claimed, and the check for the ones that have not.
class MiningRewardsScreen extends ConsumerWidget {
  const MiningRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final forced = ref.watch(forcedRewardsOutcomeProvider);

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsScreen),
      appBar: V2AppBar(title: l10n.settingsMiningRewards),
      mainContent: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            l10n.miningRewardsHeroTitle(AppConstants.tokenSymbol),
            style: text.titleHero.copyWith(color: colors.textContent),
          ),
          const SizedBox(height: 16),
          Text(l10n.miningRewardsHeroBody, style: text.bodyLarge.copyWith(color: colors.textMuted)),
          const SizedBox(height: 32),
          Text(l10n.miningRewardsWalletsLabel.toUpperCase(), style: text.labelData.copyWith(color: colors.textMuted)),
          const SizedBox(height: 4),
          for (final walletIndex in getNonHardwareWalletIndices(accounts)) ...[
            _WalletRow(walletIndex: walletIndex),
            const MenuDivider(),
          ],
          if (ref.watch(debugMiningRewardsProvider)) ...[
            const SizedBox(height: 24),
            Text('DEBUG: pick the rewards outcome', style: text.caption.copyWith(color: colors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final outcome in [...DebugMiningRewardsService.outcomes, null])
                  IntrinsicWidth(
                    child: QuantusButton.simple(
                      label: outcome ?? 'real',
                      onTap: () => ref.read(forcedRewardsOutcomeProvider.notifier).state = outcome,
                      variant: forced == outcome ? ButtonVariant.primary : ButtonVariant.staged,
                      width: null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.miningRewardsCheckEligibilityButton),
          label: l10n.miningRewardsCheckEligibility,
          onTap: () => pushForSoftwareWallet(
            context,
            ref,
            accounts,
            destination: (walletIndex) => MiningRewardsWalletScreen(walletIndex: walletIndex),
          ),
        ),
      ),
    );
  }
}

/// One wallet and what it has claimed so far; tapping opens its rewards.
class _WalletRow extends ConsumerWidget {
  final int walletIndex;

  const _WalletRow({required this.walletIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final record = ref.watch(airdropClaimRecordProvider(walletIndex));

    return GestureDetector(
      key: Key(E2EKeys.miningRewardsWalletRow(walletIndex)),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MiningRewardsWalletScreen(walletIndex: walletIndex)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                walletDisplayName(ref, l10n, walletIndex),
                style: text.bodyLarge.copyWith(color: colors.textContent),
              ),
            ),
            if (record == null)
              Text(l10n.miningRewardsNotClaimed, style: text.bodyLarge.copyWith(color: colors.textMuted))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ref
                        .watch(numberFormattingServiceProvider)
                        .formatHundredths(record.rewardHundredths, addSymbol: true),
                    style: text.bodyLarge.copyWith(color: colors.semanticSage),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.miningRewardsClaimedTag, style: text.caption.copyWith(color: colors.textMuted)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
