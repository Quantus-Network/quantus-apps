import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

Future<void> showCancelConfirmSheet(
  BuildContext context, {
  required MultisigAccount msig,
  required MultisigProposal proposal,
}) async {
  await BottomSheetContainer.show<void>(
    context,
    builder: (_) => _CancelConfirmSheet(msig: msig, proposal: proposal),
  );
}

class _CancelConfirmSheet extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final MultisigProposal proposal;

  const _CancelConfirmSheet({required this.msig, required this.proposal});

  @override
  ConsumerState<_CancelConfirmSheet> createState() => _CancelConfirmSheetState();
}

class _CancelConfirmSheetState extends ConsumerState<_CancelConfirmSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final l10n = ref.read(l10nProvider);
    final authed = await LocalAuthService().authenticate(localizedReason: l10n.multisigCancelAuthReason);
    if (!authed || !mounted) {
      setState(() {
        _submitting = false;
        _error = l10n.multisigApproveAuthRequired;
      });
      return;
    }
    try {
      final signer = ref.read(accountsProvider).value?.firstWhere(
            (a) => a.accountId == widget.msig.myMemberAccountId,
            orElse: () => throw Exception('Member account not found in local wallet'),
          );
      if (signer == null) throw Exception('No signer account available');

      await ref.read(multisigServiceProvider).cancel(
            msig: widget.msig,
            signer: signer,
            proposalId: widget.proposal.id,
          );
      ref.invalidate(multisigOpenProposalsProvider(widget.msig));
      ref.invalidate(multisigPastProposalsProvider(widget.msig));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
    } catch (e, st) {
      debugPrint('Cancel submit error: $e $st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ref.read(l10nProvider).multisigCancelFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    return BottomSheetContainer(
      title: l10n.multisigCancelConfirmTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.multisigCancelConfirmBody,
            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: text.detail?.copyWith(color: colors.textError)),
          ],
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: l10n.multisigCancelConfirmYes,
            variant: ButtonVariant.danger,
            isLoading: _submitting,
            isDisabled: _submitting,
            onTap: _confirm,
          ),
          const SizedBox(height: 12),
          QuantusButton.simple(
            label: l10n.multisigCancelConfirmKeep,
            variant: ButtonVariant.outline,
            onTap: _submitting ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
