import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/rewards_hero.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

class MiningRewardsSubmittedScreen extends ConsumerWidget {
  final int walletIndex;
  final int rewardHundredths;
  final ClaimDestination destination;

  const MiningRewardsSubmittedScreen({
    super.key,
    required this.walletIndex,
    required this.rewardHundredths,
    required this.destination,
  });

  void _done(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final body = text.bodyLarge.copyWith(color: colors.textMuted);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(context);
      },
      child: ScaffoldBase(
        key: const Key(E2EKeys.miningRewardsSubmittedScreen),
        appBar: V2AppBar(
          title: walletDisplayName(ref, l10n, walletIndex),
          leading: AppBackButton(onTap: () => _done(context)),
        ),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RewardsHero(
              label: l10n.miningRewardsTotalRewards,
              amount: fmt.formatHundredths(rewardHundredths),
              unit: AppConstants.tokenSymbol,
              amountColor: colors.semanticSage,
            ),
            const SizedBox(height: 32),
            Text(l10n.miningRewardsSubmittedAll, style: body),
            const SizedBox(height: 12),
            Text(l10n.miningRewardsSubmittedPayingTo(destination.label), style: body),
            const SizedBox(height: 12),
            Text(l10n.miningRewardsSubmittedNote, style: body),
          ],
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(
            key: const Key(E2EKeys.miningRewardsSubmittedDoneButton),
            label: l10n.commonDone,
            variant: ButtonVariant.staged,
            onTap: () => _done(context),
          ),
        ),
      ),
    );
  }
}
