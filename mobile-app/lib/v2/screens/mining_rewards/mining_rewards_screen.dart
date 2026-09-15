import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_eligibility_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

/// Entry to the testnet mining rewards claim: pick a wallet, see what it
/// mined on each testnet, choose where the reward is paid.
class MiningRewardsScreen extends ConsumerWidget {
  const MiningRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsScreen),
      appBar: V2AppBar(title: l10n.settingsMiningRewards),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(l10n.miningRewardsIntro, style: text.body.copyWith(color: colors.textMuted))],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.miningRewardsCheckEligibilityButton),
          label: l10n.miningRewardsCheckEligibility,
          onTap: () => pushForSoftwareWallet(
            context,
            ref,
            ref.read(accountsProvider).value ?? const [],
            destination: (walletIndex) => MiningRewardsEligibilityScreen(walletIndex: walletIndex),
          ),
        ),
      ),
    );
  }
}
