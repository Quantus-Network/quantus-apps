import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/account_list_row.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_address_screen.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_confirm_screen.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/rewards_hero.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

/// Where the rewards are paid: one of the user's own accounts, or on to a
/// typed address.
class MiningRewardsPayToScreen extends ConsumerStatefulWidget {
  final int walletIndex;
  final List<ChainRewards> rewards;

  const MiningRewardsPayToScreen({super.key, required this.walletIndex, required this.rewards});

  @override
  ConsumerState<MiningRewardsPayToScreen> createState() => _MiningRewardsPayToScreenState();
}

class _MiningRewardsPayToScreenState extends ConsumerState<MiningRewardsPayToScreen> {
  Account? _picked;

  void _continue(Account account) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MiningRewardsConfirmScreen(
        walletIndex: widget.walletIndex,
        rewards: widget.rewards,
        destination: ClaimDestination(address: account.accountId, accountName: account.name),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final wallets = groupWallets(accounts: ref.watch(accountsProvider).value ?? const [], multisigs: const []).wallets;
    final active = ref.watch(activeAccountProvider).value;
    final selected = _picked ?? (active is RegularAccount ? active.account : wallets.firstOrNull?.accounts.firstOrNull);

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsPayToScreen),
      appBar: V2AppBar(title: walletDisplayName(ref, l10n, widget.walletIndex)),
      mainContent: ListView(
        padding: EdgeInsets.zero,
        children: [
          RewardsHero(
            label: l10n.miningRewardsTotalRewards,
            amount: fmt.formatHundredths(totalRewardHundredths(widget.rewards)),
            unit: AppConstants.tokenSymbol,
            amountColor: colors.semanticSage,
          ),
          const SizedBox(height: 16),
          Text(l10n.miningRewardsPayToIntro, style: text.bodyLarge.copyWith(color: colors.textMuted)),
          const SizedBox(height: 24),
          for (final wallet in wallets) ...[
            Text(
              walletDisplayName(ref, l10n, wallet.walletIndex).toUpperCase(),
              style: text.labelData.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            for (final account in wallet.accounts)
              _row(account, selected, leading: AccountBadge.account(account: account, isActive: true)),
            if (wallet.encryptedAccount case final encrypted?)
              _row(encrypted, selected, leading: const EncryptedLockBadge()),
            const SizedBox(height: 12),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuantusButton.simple(
              key: const Key(E2EKeys.miningRewardsContinueButton),
              label: l10n.commonContinue,
              isDisabled: selected == null,
              onTap: selected == null ? null : () => _continue(selected),
            ),
            const SizedBox(height: 10),
            QuantusButton.simple(
              key: const Key(E2EKeys.miningRewardsUseAnotherAddressButton),
              label: l10n.miningRewardsUseAnotherAddress,
              variant: ButtonVariant.staged,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MiningRewardsAddressScreen(walletIndex: widget.walletIndex, rewards: widget.rewards),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Account account, Account? selected, {required Widget leading}) {
    final colors = context.colorsV3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AccountListRow(
        isSelected: true,
        onTap: () => setState(() => _picked = account),
        leading: leading,
        title: account.name,
        subtitle: AddressFormattingService.formatAddress(account.accountId),
        trailing: account.accountId == selected?.accountId
            ? Icon(Icons.check, color: colors.accentFlare, size: 20)
            : null,
      ),
    );
  }
}
