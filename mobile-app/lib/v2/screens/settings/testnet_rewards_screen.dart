import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

class TestnetRewardsScreen extends ConsumerWidget {
  const TestnetRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final miningAsync = ref.watch(miningRewardsProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsTestnetTitle),
      mainContent: miningAsync.when(
        skipLoadingOnRefresh: false,
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(miningRewardsProvider),
          child: _buildContent(context, l10n, data, colors, text),
        ),
        loading: () => const Center(child: Loader()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.settingsTestnetLoadError, style: text.body.copyWith(color: colors.textContent)),
              const SizedBox(height: 8),
              Text(l10n.settingsMiningCheckConnection, style: text.caption.copyWith(color: colors.textMuted)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => ref.invalidate(miningRewardsProvider),
                child: Text(l10n.posQrTryAgain, style: text.body.copyWith(color: colors.accentFlare)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    MiningRewardsData data,
    AppColorsV3 colors,
    AppTextThemeV3 text,
  ) {
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
          decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
          child: Column(
            children: [
              const Text('💰', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                l10n.settingsTestnetTotalBlocks(data.totalBlocks),
                style: text.displayBalance.copyWith(color: colors.semanticSage),
              ),
              const SizedBox(height: 8),
              Text(l10n.settingsTestnetTotalDescription, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(l10n.settingsTestnetBreakdown, style: text.headingRow.copyWith(color: colors.textContent)),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
          child: Column(
            children: [
              for (var i = 0; i < testnets.length; i++) ...[
                if (i > 0) const Padding(padding: EdgeInsets.only(top: 16, bottom: 24), child: MenuDivider()),
                Row(
                  children: [
                    Expanded(
                      child: Text(testnets[i].$1, style: text.body.copyWith(color: colors.textContent)),
                    ),
                    const Text('💰 ', style: TextStyle(fontSize: 14)),
                    Text(
                      l10n.settingsTestnetRowBlocks(testnets[i].$2),
                      style: text.bodyEmphasis.copyWith(color: colors.semanticSage),
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
