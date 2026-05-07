import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class MiningRewardsScreen extends ConsumerWidget {
  const MiningRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final miningAsync = ref.watch(miningRewardsProvider);
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase.refreshable(
      appBar: const V2AppBar(title: 'Mining Rewards'),
      onRefresh: () async => ref.invalidate(miningRewardsProvider),
      slivers: [
        miningAsync.when(
          data: (data) => data.totalBlocks > 0 ? _WithRewards(data: data) : const _NoRewards(),
          loading: () => const _NoRewards(isLoading: true),
          error: (err, _) =>
              _ErrorState(colors: colors, text: text, onRetry: () => ref.invalidate(miningRewardsProvider)),
        ),
      ],
    );
  }
}

class _WithRewards extends ConsumerWidget {
  final MiningRewardsData data;

  const _WithRewards({required this.data});

  static const _resonanceSince = 'Jul 2025';
  static const _schrodingerSince = 'Oct 2025';
  static const _diracSince = 'Nov 2025';
  static const _planckSince = 'Jan 2026';

  String get _activeSince {
    if (data.resonanceBlocks > 0) return _resonanceSince;
    if (data.schrodingerBlocks > 0) return _schrodingerSince;
    if (data.diracBlocks > 0) return _diracSince;
    return _planckSince;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numberFmt = ref.watch(numberFormattingServiceProvider);
    final quanEarned = numberFmt.formatBalance(data.planckRewards, maxDecimals: 1);

    final colors = context.colors;
    final text = context.themeText;

    final testnets = [
      _TestnetEntry('Dirac', _diracSince, data.diracBlocks),
      _TestnetEntry('Schrödinger', _schrodingerSince, data.schrodingerBlocks),
      _TestnetEntry('Resonance', _resonanceSince, data.resonanceBlocks),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SplitCard(
          topChild: _CardTopSection(
            totalBlocks: data.planckBlocks,
            totalBlocksColor: colors.success,
            statusLabel: 'Mining',
            statusColor: colors.success,
          ),
          bottomChild: Row(
            children: [
              _StatColumn(label: 'QUAN EARNED', value: quanEarned, valueColor: colors.accentOrange),
              const SizedBox(width: 64),
              _StatColumn(label: 'ACTIVE SINCE', value: _activeSince, valueColor: colors.textPrimary),
            ],
          ),
        ),
        const SizedBox(height: 32),
        for (var i = 0; i < testnets.length; i++) ...[
          _TestnetRow(entry: testnets[i]),
          if (i < testnets.length - 1) Divider(color: colors.toasterBackground, height: 1, thickness: 1),
        ],
        const SizedBox(height: 48),
        Center(
          child: _OrangeLinkButton(
            label: 'View Telemetry ↗',
            text: text,
            onTap: () => openUrl(AppConstants.telemetryUrl),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NoRewards extends StatelessWidget {
  final bool isLoading;

  const _NoRewards({this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SplitCard(
          topChild: _CardTopSection(
            totalBlocks: 0,
            totalBlocksColor: colors.textTertiary,
            statusLabel: 'Pending',
            statusColor: colors.textTertiary,
            isLoading: isLoading,
          ),
          bottomChild: _StatColumn(
            label: 'QUAN EARNED',
            value: '0.00',
            valueColor: colors.textTertiary,
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
            if (i < 3) Divider(color: colors.toasterBackground, height: 1, thickness: 1),
            const SizedBox(height: 24),
          ],
        ] else ...[
          const SizedBox(height: 64),
          Text(
            'No mining data yet',
            style: text.mediumTitle?.copyWith(fontWeight: FontWeight.w400, color: colors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up a Quantus mining node to start earning rewards.',
            textAlign: TextAlign.center,
            style: text.smallParagraph?.copyWith(color: colors.txItemIconDefault, height: 1.35),
          ),
          const SizedBox(height: 64),
          _OrangeLinkButton(
            label: 'Mining Setup Guide ↗',
            text: text,
            onTap: () => openUrl(AppConstants.miningSetupGuideUrl),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _CardTopSection extends StatelessWidget {
  final int totalBlocks;
  final Color totalBlocksColor;
  final String statusLabel;
  final Color statusColor;
  final bool isLoading;

  const _CardTopSection({
    required this.totalBlocks,
    required this.totalBlocksColor,
    required this.statusLabel,
    required this.statusColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('BLOCKS MINED', style: text.receiveLabel?.copyWith(color: colors.textLabel)),
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
                  Text(statusLabel, style: text.smallParagraph?.copyWith(color: statusColor)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Skeleton(width: 100, height: 24)
        else
          Text('$totalBlocks', style: text.totalMinedBlocks?.copyWith(color: totalBlocksColor)),
        const SizedBox(height: 4),
        Text('on the Planck testnet', style: text.detail?.copyWith(color: colors.textMuted)),
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
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
        const SizedBox(height: 8),
        if (isLoading)
          const Skeleton(width: 100, height: 24)
        else
          Text(value, style: text.sendSectionLabel?.copyWith(color: valueColor)),
      ],
    );
  }
}

class _TestnetRow extends StatelessWidget {
  final _TestnetEntry entry;

  const _TestnetRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final countColor = colors.textLightGray;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name, style: text.smallTitle?.copyWith(fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Text(entry.subtitle, style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${entry.blocks}',
                style: text.smallTitle?.copyWith(
                  fontFamily: AppTextTheme.fontFamilySecondary,
                  fontWeight: FontWeight.w400,
                  color: countColor,
                ),
              ),
              const SizedBox(height: 4),
              Text('blocks', style: text.detail?.copyWith(color: colors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrangeLinkButton extends StatelessWidget {
  final String label;
  final AppTextTheme text;
  final VoidCallback onTap;

  const _OrangeLinkButton({required this.label, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.accentOrange, width: 1)),
        ),
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(label, style: text.smallParagraph?.copyWith(color: colors.accentOrange)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final AppColorsV2 colors;
  final AppTextTheme text;
  final VoidCallback onRetry;

  const _ErrorState({required this.colors, required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load mining rewards', style: text.paragraph?.copyWith(color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text('Please check your connection', style: text.detail?.copyWith(color: colors.textTertiary)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Try Again',
                style: text.smallParagraph?.copyWith(color: colors.accentGreen, fontWeight: FontWeight.w600),
              ),
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
