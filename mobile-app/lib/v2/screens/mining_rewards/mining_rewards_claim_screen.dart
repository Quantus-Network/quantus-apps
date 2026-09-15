import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/account_list_row.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_submitted_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';

/// Where the rewards are paid: one of the user's own accounts, or any address.
class MiningRewardsClaimScreen extends ConsumerStatefulWidget {
  final int walletIndex;
  final List<ChainRewards> eligibilities;

  const MiningRewardsClaimScreen({super.key, required this.walletIndex, required this.eligibilities});

  @override
  ConsumerState<MiningRewardsClaimScreen> createState() => _MiningRewardsClaimScreenState();
}

class _MiningRewardsClaimScreenState extends ConsumerState<MiningRewardsClaimScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _isValid = false;
  String? _checksum;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onAddressChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _address => _controller.text.trim();

  void _onAddressChanged() {
    final address = _address;
    final isValid = address.isNotEmpty && ref.read(substrateServiceProvider).isValidSS58Address(address);
    setState(() {
      _isValid = isValid;
      _checksum = null;
    });
    if (!isValid) return;
    ref.read(humanReadableChecksumServiceProvider).getHumanReadableName(address).then((checksum) {
      if (mounted && _address == address) setState(() => _checksum = checksum);
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(miningRewardsServiceProvider)
          .submitClaims(
            walletIndex: widget.walletIndex,
            matches: [
              for (final e in widget.eligibilities)
                if (e.isEligible) ...e.matches,
            ],
            claimAccount: _address,
          );
    } catch (e) {
      quantusPrint('Mining rewards claim failed: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showErrorToaster(message: ref.read(l10nProvider).miningRewardsSubmitFailed('$e'));
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MiningRewardsSubmittedScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final wallets = groupWallets(accounts: ref.watch(accountsProvider).value ?? const [], multisigs: const []).wallets;

    return ScaffoldBase(
      key: const Key(E2EKeys.miningRewardsClaimScreen),
      appBar: V2AppBar(title: l10n.miningRewardsClaimTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.miningRewardsBeneficiaryLabel, style: text.headingRow.copyWith(color: colors.textContent)),
          const SizedBox(height: 12),
          AddressInputField(
            controller: _controller,
            focusNode: _focus,
            fieldKey: const Key(E2EKeys.miningRewardsBeneficiaryField),
            hasValid: _isValid,
            recipientChecksum: _checksum,
            hintText: l10n.sendSelectRecipientSearchHint(AppConstants.tokenSymbol),
          ),
          const SizedBox(height: 28),
          Text(l10n.miningRewardsYourAccounts, style: text.headingRow.copyWith(color: colors.textContent)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                for (final wallet in wallets) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      walletDisplayName(ref, l10n, wallet.walletIndex),
                      style: text.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                  for (final account in wallet.accounts)
                    _accountRow(account, leading: AccountBadge.account(account: account, isActive: true)),
                  if (wallet.encryptedAccount case final encrypted?)
                    _accountRow(encrypted, leading: const EncryptedLockBadge()),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.miningRewardsPayoutInfo, style: text.caption.copyWith(color: colors.textMuted)),
            const SizedBox(height: 24),
            QuantusButton.simple(
              key: const Key(E2EKeys.miningRewardsSubmitButton),
              label: l10n.miningRewardsSubmitClaims,
              isDisabled: !_isValid,
              isLoading: _submitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountRow(Account account, {required Widget leading}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AccountListRow(
      isSelected: true,
      isHighlighted: account.accountId == _address,
      onTap: () => _controller.text = account.accountId,
      leading: leading,
      title: account.name,
      subtitle: AddressFormattingService.formatAddress(account.accountId),
    ),
  );
}
