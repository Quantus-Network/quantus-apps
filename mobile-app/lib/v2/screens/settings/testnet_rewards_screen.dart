import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class TestnetRewardsScreen extends ConsumerWidget {
  const TestnetRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final miningAsync = ref.watch(miningRewardsProvider);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Testnet Rewards'),
      mainContent: miningAsync.when(
        skipLoadingOnRefresh: false,
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(miningRewardsProvider),
          child: _buildContent(data, colors, text),
        ),
        loading: () => const Center(child: Loader()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load testnet rewards', style: text.paragraph?.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 8),
              Text('Please check your connection', style: text.detail?.copyWith(color: colors.textTertiary)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => ref.invalidate(miningRewardsProvider),
                child: Text(
                  'Try Again',
                  style: text.smallParagraph?.copyWith(color: colors.accentGreen, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(MiningRewardsData data, AppColorsV2 colors, AppTextTheme text) {
    final testnets = [
      ('Planck', data.planckBlocks),
      ('Dirac', data.diracBlocks),
      ('Schrödinger', data.schrodingerBlocks),
      ('Resonance', data.resonanceBlocks),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              const Text('💰', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                '${data.totalBlocks} blocks',
                style: text.largeTitle?.copyWith(color: colors.accentGreen, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Total blocks mined across all testnets', style: text.detail?.copyWith(color: colors.textTertiary)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Breakdown',
            style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              for (var i = 0; i < testnets.length; i++) ...[
                if (i > 0) const SettingsDivider(style: SettingsDividerStyle.cardInterior),
                
                Row(
                  children: [
                    Expanded(
                      child: Text(testnets[i].$1, style: text.paragraph?.copyWith(color: colors.textPrimary)),
                    ),
                    const Text('💰 ', style: TextStyle(fontSize: 14)),
                    Text(
                      '${testnets[i].$2} blocks',
                      style: text.smallParagraph?.copyWith(color: colors.accentGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
