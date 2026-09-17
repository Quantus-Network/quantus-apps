import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/chain_rewards_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_pay_to_screen.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/rewards_hero.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

/// One wallet's testnet rewards: the check running chain by chain, then the
/// result, or the claim it already submitted.
class MiningRewardsWalletScreen extends ConsumerWidget {
  final int walletIndex;

  const MiningRewardsWalletScreen({super.key, required this.walletIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final walletName = walletDisplayName(ref, l10n, walletIndex);
    final record = ref.watch(airdropClaimRecordProvider(walletIndex));
    if (record != null) return _ClaimedView(walletName: walletName, record: record);

    final colors = context.colorsV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final checks = [for (final chain in TestnetChain.values) (walletIndex: walletIndex, chain: chain)];
    final results = [for (final check in checks) ref.watch(chainEligibilityProvider(check))];
    final loaded = [
      for (final result in results)
        if (!result.isLoading) ?result.value,
    ];
    final allLoaded = loaded.length == results.length;
    if (allLoaded && loaded.every((r) => r.rows.isEmpty)) return const _NoMiningView();

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsWalletScreen),
      appBar: V2AppBar(title: walletName),
      mainContent: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (allLoaded)
            RewardsHero(
              label: l10n.miningRewardsTotalRewards,
              amount: fmt.formatHundredths(totalRewardHundredths(loaded)),
              unit: AppConstants.tokenSymbol,
              amountColor: colors.semanticSage,
            )
          else
            RewardsHero(
              label: l10n.miningRewardsCheckingAddresses(_addressCount(ref)),
              amount: '${loaded.length}',
              unit: l10n.miningRewardsProgressOf(results.length),
            ),
          const SizedBox(height: 32),
          for (final (i, check) in checks.indexed) ...[
            _ChainRow(check: check, result: results[i], resultsMode: allLoaded, l10n: l10n),
            const MenuDivider(),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.miningRewardsClaimButton),
          label: l10n.miningRewardsClaim,
          isDisabled: !allLoaded || !loaded.any((r) => r.isEligible),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MiningRewardsPayToScreen(walletIndex: walletIndex, rewards: loaded),
            ),
          ),
        ),
      ),
    );
  }

  /// Accounts the wallet holds, including its encrypted one.
  int _addressCount(WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return accounts.where((a) => a.walletIndex == walletIndex).length;
  }
}

class _ChainRow extends ConsumerWidget {
  final ChainCheck check;
  final AsyncValue<ChainRewards> result;
  final bool resultsMode;
  final AppLocalizations l10n;

  const _ChainRow({required this.check, required this.result, required this.resultsMode, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final rewards = result.isLoading ? null : result.value;
    final mined = rewards != null && rewards.rows.isNotEmpty;

    final Widget trailing;
    if (result.isLoading) {
      trailing = const Loader();
    } else if (rewards == null) {
      trailing = GestureDetector(
        onTap: () => ref.invalidate(chainEligibilityProvider(check)),
        child: Text(l10n.miningRewardsCheckFailed, style: text.caption.copyWith(color: colors.semanticEmber)),
      );
    } else if (!mined) {
      trailing = Text(l10n.miningRewardsNotMined, style: text.bodyLarge.copyWith(color: colors.textMuted));
    } else {
      trailing = Text(
        fmt.formatHundredths(rewards.rewardHundredths, addSymbol: !resultsMode),
        style: text.bodyLarge.copyWith(color: colors.semanticSage),
      );
    }

    return GestureDetector(
      key: Key(E2EKeys.miningRewardsChainRow(check.chain.name)),
      onTap: mined ? () => showChainRewardsSheet(context, rewards) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(check.chain.displayName, style: text.bodyLarge.copyWith(color: colors.textContent)),
                  if (resultsMode && mined) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.miningRewardsBlocks(rewards.blocksMined),
                      style: text.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _NoMiningView extends ConsumerWidget {
  const _NoMiningView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final body = text.bodyLarge.copyWith(color: colors.textMuted);

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsNoMiningScreen),
      appBar: V2AppBar(title: l10n.settingsMiningRewards),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.miningRewardsNoMiningTitle, style: text.titleHero.copyWith(color: colors.textContent)),
          const SizedBox(height: 16),
          Text(l10n.miningRewardsNoMiningBody1, style: body),
          const SizedBox(height: 16),
          Text(l10n.miningRewardsNoMiningBody2, style: body),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.miningRewardsTryAnotherWalletButton),
          label: l10n.miningRewardsTryAnotherWallet,
          variant: ButtonVariant.staged,
          onTap: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _ClaimedView extends ConsumerWidget {
  final String walletName;
  final AirdropClaimRecord record;

  const _ClaimedView({required this.walletName, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final labelStyle = text.bodyLarge.copyWith(color: colors.textContent);
    const rowPadding = EdgeInsets.symmetric(vertical: 14);

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsClaimedScreen),
      appBar: V2AppBar(title: walletName),
      mainContent: ListView(
        padding: EdgeInsets.zero,
        children: [
          RewardsHero(
            label: l10n.miningRewardsClaimedOn(
              DatetimeFormattingService.formatDayMonth(record.claimedAt, l10n.localeName),
            ),
            amount: fmt.formatHundredths(record.rewardHundredths),
            unit: AppConstants.tokenSymbol,
            amountColor: colors.semanticSage,
          ),
          const SizedBox(height: 32),
          DetailSummaryRow(
            label: l10n.miningRewardsPayingTo,
            value: AddressFormattingService.formatAddress(record.claimAccount),
            monospace: true,
            labelStyle: labelStyle,
            padding: rowPadding,
          ),
          const MenuDivider(),
          DetailSummaryRow(
            label: l10n.miningRewardsNextPayout,
            value: l10n.miningRewardsPayoutDay,
            labelStyle: labelStyle,
            padding: rowPadding,
          ),
          const MenuDivider(),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.miningRewardsCheckAnotherWalletButton),
          label: l10n.miningRewardsCheckAnotherWallet,
          variant: ButtonVariant.staged,
          onTap: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
