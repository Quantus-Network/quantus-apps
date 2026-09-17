import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_submitted_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

/// Last look at amount and destination before the claims are proved and sent.
class MiningRewardsConfirmScreen extends ConsumerStatefulWidget {
  final int walletIndex;
  final List<ChainRewards> rewards;
  final ClaimDestination destination;

  const MiningRewardsConfirmScreen({
    super.key,
    required this.walletIndex,
    required this.rewards,
    required this.destination,
  });

  @override
  ConsumerState<MiningRewardsConfirmScreen> createState() => _MiningRewardsConfirmScreenState();
}

class _MiningRewardsConfirmScreenState extends ConsumerState<MiningRewardsConfirmScreen> {
  bool _submitting = false;
  bool _failed = false;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      await ref
          .read(miningRewardsServiceProvider)
          .submitClaims(walletIndex: widget.walletIndex, rewards: widget.rewards, destination: widget.destination);
    } catch (e) {
      quantusPrint('Mining rewards claim failed: $e');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    ref.invalidate(airdropClaimRecordProvider(widget.walletIndex));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MiningRewardsSubmittedScreen(
          walletIndex: widget.walletIndex,
          rewardHundredths: totalRewardHundredths(widget.rewards),
          destination: widget.destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amount = fmt.formatHundredths(totalRewardHundredths(widget.rewards), addSymbol: true);

    if (_failed) {
      final body = text.bodyLarge.copyWith(color: colors.textMuted);
      return ScaffoldBase(
        key: const Key(E2EKeys.miningRewardsSubmitFailedScreen),
        appBar: V2AppBar(
          title: walletDisplayName(ref, l10n, widget.walletIndex),
          leading: AppBackButton(onTap: () => setState(() => _failed = false)),
        ),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.miningRewardsSubmitFailedTitle, style: text.titleHero.copyWith(color: colors.textContent)),
            const SizedBox(height: 16),
            Text(l10n.miningRewardsSubmitFailedBody1, style: body),
            const SizedBox(height: 16),
            Text(l10n.miningRewardsSubmitFailedBody2, style: body),
          ],
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(
            key: const Key(E2EKeys.miningRewardsTryAgainButton),
            label: l10n.commonTryAgain,
            onTap: _submit,
          ),
        ),
      );
    }

    final checksum = ref.watch(checksumNameProvider(widget.destination.address));
    final label = text.labelData.copyWith(color: colors.textMuted);

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsConfirmScreen),
      appBar: V2AppBar(title: l10n.miningRewardsConfirmTitle),
      mainContent: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.miningRewardsClaimingLabel.toUpperCase(), style: label),
                      const SizedBox(height: 12),
                      Text(amount, style: text.displayBalance.copyWith(color: colors.textContent)),
                    ],
                  ),
                ),
                const MenuDivider(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.sendTxSubmittedToLabel.toUpperCase(), style: label),
                      const SizedBox(height: 12),
                      AddressCheckphraseWithInitial(
                        recipientChecksum: checksum.value ?? '',
                        recipientAddress: widget.destination.address,
                        showFullAddress: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          DetailSummaryRow(
            label: l10n.sendTxSubmittedToLabel.toUpperCase(),
            value: AddressFormattingService.formatAddress(widget.destination.address),
            monospace: true,
          ),
          DetailSummaryRow(label: l10n.miningRewardsAmountLabel.toUpperCase(), value: amount),
          DetailSummaryRow(label: l10n.miningRewardsPayoutLabel.toUpperCase(), value: l10n.miningRewardsPayoutDay),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuantusButton.simple(
              key: const Key(E2EKeys.miningRewardsSubmitButton),
              label: l10n.miningRewardsSubmitClaims,
              isLoading: _submitting,
              onTap: _submit,
            ),
            const SizedBox(height: 10),
            QuantusButton.simple(
              key: const Key(E2EKeys.miningRewardsChangeDetailsButton),
              label: l10n.miningRewardsChangeDetails,
              variant: ButtonVariant.staged,
              isDisabled: _submitting,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
