import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/screens/settings/redeem_address_screen.dart';

class MiningRewardsScreen extends ConsumerWidget {
  const MiningRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final miningAsync = ref.watch(miningRewardsProvider);

    return ScaffoldBase.refreshable(
      appBar: V2AppBar(title: l10n.settingsMiningTitle),
      onRefresh: () async => ref.invalidate(miningRewardsProvider),
      slivers: [
        miningAsync.when(
          data: (data) => data.totalBlocks > 0 ? _WithRewards(data: data) : _NoRewards(l10n: l10n),
          loading: () => _NoRewards(l10n: l10n, isLoading: true),
          error: (err, _) => _ErrorState(l10n: l10n, onRetry: () => ref.invalidate(miningRewardsProvider)),
        ),
      ],
      bottomContent: miningAsync.when(
        data: (data) {
          if (data.totalBlocks == 0) return null;
          final canRedeem = data.redeemableRewards > BigInt.zero;
          return ScaffoldBaseBottomContent(
            child: QuantusButton.simple(
              label: l10n.settingsMiningRedeem,
              isDisabled: !canRedeem,
              onTap: canRedeem
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RedeemAddressScreen(redeemableRewards: data.redeemableRewards)),
                    )
                  : null,
            ),
          );
        },
        loading: () => null,
        error: (err, _) => null,
      ),
    );
  }
}

class _WithRewards extends ConsumerWidget {
  final MiningRewardsData data;

  const _WithRewards({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final numberFmt = ref.watch(numberFormattingServiceProvider);
    final tokenEarned = numberFmt.formatBalance(data.planckRewards, smartDecimals: 2, addSymbol: true);
    final redeemedRewards = numberFmt.formatBalance(data.redeemedRewards, smartDecimals: 2, addSymbol: true);
    final redeemableRewards = numberFmt.formatBalance(data.redeemableRewards, smartDecimals: 2, addSymbol: true);

    final colors = context.colorsV3;

    final testnets = [
      _TestnetEntry('Dirac', l10n.settingsMiningDiracSince, data.diracBlocks),
      _TestnetEntry('Schrödinger', l10n.settingsMiningSchrodingerSince, data.schrodingerBlocks),
      _TestnetEntry('Resonance', l10n.settingsMiningResonanceSince, data.resonanceBlocks),
    ];

    final miningSummaryPairRows = [
      _StatPairRow(
        left: _MiningStatCell(
          label: l10n.settingsMiningStatTestnetBlocks,
          value: '${data.totalBlocks}',
          valueColor: colors.textMuted,
        ),
        right: _MiningStatCell(
          label: l10n.settingsMiningStatTestnetRewards,
          value: tokenEarned,
          valueColor: colors.accentFlare,
        ),
      ),
      _StatPairRow(
        left: _MiningStatCell(
          label: l10n.settingsMiningStatRedeemed,
          value: redeemedRewards,
          valueColor: colors.textMuted,
        ),
        right: _MiningStatCell(
          label: l10n.settingsMiningStatRedeemable,
          value: redeemableRewards,
          valueColor: colors.semanticSage,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SplitCard(
          topChild: _CardTopSection(
            l10n: l10n,
            totalBlocks: data.totalBlocks,
            totalBlocksColor: colors.textMuted,
            statusLabel: l10n.settingsMiningStatusMining,
            statusColor: colors.semanticSage,
          ),
          bottomChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < miningSummaryPairRows.length; i++) ...[
                if (i > 0) const SizedBox(height: 24),
                miningSummaryPairRows[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        for (var i = 0; i < testnets.length; i++) ...[
          _TestnetRow(entry: testnets[i], blocksLabel: l10n.settingsMiningTestnetBlocks),
          if (i < testnets.length - 1) const MenuDivider(),
        ],
        const SizedBox(height: 48),
        Center(
          child: _FlareLinkButton(
            label: l10n.settingsMiningViewTelemetry,
            onTap: () => openUrl(AppConstants.telemetryUrl),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NoRewards extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isLoading;

  const _NoRewards({required this.l10n, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SplitCard(
          topChild: _CardTopSection(
            l10n: l10n,
            totalBlocks: 0,
            totalBlocksColor: colors.textMuted,
            statusLabel: l10n.settingsMiningStatusPending,
            statusColor: colors.textMuted,
            isLoading: isLoading,
          ),
          bottomChild: _StatColumn(
            label: l10n.settingsMiningTokenEarned(AppConstants.tokenSymbol),
            value: '0.00',
            valueColor: colors.textMuted,
            isLoading: isLoading,
          ),
        ),
        if (isLoading) ...[
          const SizedBox(height: 32),
          for (var i = 0; i < 4; i++) ...[
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Skeleton(width: 100), SizedBox(height: 8), Skeleton(width: 72)],
                  ),
                ),
                Spacer(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [Skeleton(width: 72), SizedBox(height: 8), Skeleton(width: 56)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (i < 3) const MenuDivider(),
            const SizedBox(height: 24),
          ],
        ] else ...[
          const SizedBox(height: 64),
          Text(l10n.settingsMiningNoDataTitle, style: text.titleScreen.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          Text(
            l10n.settingsMiningNoDataBody,
            textAlign: TextAlign.center,
            style: text.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 64),
          _FlareLinkButton(
            label: l10n.settingsMiningSetupGuide,
            onTap: () => openUrl(AppConstants.miningSetupGuideUrl),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _CardTopSection extends StatelessWidget {
  final AppLocalizations l10n;
  final int totalBlocks;
  final Color totalBlocksColor;
  final String statusLabel;
  final Color statusColor;
  final bool isLoading;

  const _CardTopSection({
    required this.l10n,
    required this.totalBlocks,
    required this.totalBlocksColor,
    required this.statusLabel,
    required this.statusColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.settingsMiningBlocksMined, style: text.labelData.copyWith(color: colors.textMuted)),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                if (isLoading)
                  const Skeleton(width: 100, height: 24)
                else
                  Text(statusLabel, style: text.caption.copyWith(color: statusColor)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Skeleton(width: 100, height: 24)
        else
          Text('$totalBlocks', style: text.displayBalance.copyWith(color: totalBlocksColor)),
        const SizedBox(height: 4),
        Text(l10n.settingsMiningBlocksAcrossTestnets, style: text.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }
}

class _MiningStatCell {
  const _MiningStatCell({required this.label, required this.value, required this.valueColor});

  final String label;
  final String value;
  final Color valueColor;
}

class _StatPairRow extends StatelessWidget {
  const _StatPairRow({required this.left, required this.right});

  final _MiningStatCell left;
  final _MiningStatCell right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatColumn(label: left.label, value: left.value, valueColor: left.valueColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatColumn(label: right.label, value: right.value, valueColor: right.valueColor),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isLoading;

  const _StatColumn({required this.label, required this.value, required this.valueColor, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelData.copyWith(color: colors.textMuted)),
        const SizedBox(height: 8),
        if (isLoading)
          const Skeleton(width: 100, height: 24)
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, softWrap: false, style: text.amountInline.copyWith(color: valueColor)),
          ),
      ],
    );
  }
}

class _TestnetRow extends StatelessWidget {
  final _TestnetEntry entry;
  final String blocksLabel;

  const _TestnetRow({required this.entry, required this.blocksLabel});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name, style: text.amountRow.copyWith(color: colors.textContent)),
              const SizedBox(height: 8),
              Text(entry.subtitle, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${entry.blocks}', style: text.amountInline.copyWith(color: colors.textMuted)),
              const SizedBox(height: 4),
              Text(blocksLabel, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlareLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FlareLinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final linkColor = colors.accentFlare;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: linkColor, width: 1)),
        ),
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(label, style: context.themeTextV3.body.copyWith(color: linkColor)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  const _ErrorState({required this.l10n, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsMiningLoadError, style: text.body.copyWith(color: colors.textContent)),
            const SizedBox(height: 8),
            Text(l10n.settingsMiningCheckConnection, style: text.caption.copyWith(color: colors.textMuted)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Text(l10n.posQrTryAgain, style: text.body.copyWith(color: colors.accentFlare)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestnetEntry {
  final String name;
  final String subtitle;
  final int blocks;

  const _TestnetEntry(this.name, this.subtitle, this.blocks);
}
