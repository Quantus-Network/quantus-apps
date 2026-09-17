import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_confirm_screen.dart';

/// Pays the rewards to an address the user types instead of one of their own.
class MiningRewardsAddressScreen extends ConsumerStatefulWidget {
  final int walletIndex;
  final List<ChainRewards> rewards;

  const MiningRewardsAddressScreen({super.key, required this.walletIndex, required this.rewards});

  @override
  ConsumerState<MiningRewardsAddressScreen> createState() => _MiningRewardsAddressScreenState();
}

class _MiningRewardsAddressScreenState extends ConsumerState<MiningRewardsAddressScreen> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  String get _address => _controller.text.trim();

  void _onChanged() =>
      setState(() => _isValid = _address.isNotEmpty && ref.read(substrateServiceProvider).isValidSS58Address(_address));

  void _continue() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MiningRewardsConfirmScreen(
        walletIndex: widget.walletIndex,
        rewards: widget.rewards,
        destination: ClaimDestination(address: _address),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final invalid = _address.isNotEmpty && !_isValid;

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsAddressScreen),
      appBar: V2AppBar(title: l10n.miningRewardsAnotherAddressTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.miningRewardsDestinationLabel.toUpperCase(),
            style: text.labelData.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          QuantusTextField(
            key: const Key(E2EKeys.miningRewardsAddressField),
            controller: _controller,
            hint: l10n.miningRewardsPasteAddressHint(AppConstants.tokenSymbol),
            error: invalid ? l10n.miningRewardsAddressInvalid(AppConstants.tokenSymbol) : null,
            maxLines: 3,
            autocorrect: false,
            enableSuggestions: false,
          ),
          if (!invalid) ...[
            const SizedBox(height: 8),
            Text(l10n.miningRewardsAddressAdvice, style: text.caption.copyWith(color: colors.textMuted)),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.miningRewardsContinueButton),
          label: l10n.commonContinue,
          isDisabled: !_isValid,
          onTap: _continue,
        ),
      ),
    );
  }
}
