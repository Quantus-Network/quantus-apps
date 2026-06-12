import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/multisig_signer_list_tile.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class MultisigDetailsScreen extends ConsumerWidget {
  const MultisigDetailsScreen({super.key, required this.account});

  final MultisigAccount account;

  List<String> _orderedSigners() {
    final creator = account.creator;
    if (creator == null || !account.signers.contains(creator)) {
      return List<String>.from(account.signers);
    }
    final rest = account.signers.where((id) => id != creator).toList();
    return [creator, ...rest];
  }

  String? _localAccountName(WidgetRef ref, String accountId) {
    final accounts = ref.watch(accountsProvider).value;
    if (accounts == null) return null;
    for (final a in accounts) {
      if (a.accountId == accountId) return a.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final signers = _orderedSigners();

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigAccountMenuDetailsTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SignersSection(
              account: account,
              signers: signers,
              localNameFor: (id) => _localAccountName(ref, id),
              colors: colors,
              text: text,
              l10n: l10n,
            ),
            const SizedBox(height: 24),
            _ThresholdSection(account: account, colors: colors, text: text, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _SignersSection extends StatelessWidget {
  const _SignersSection({
    required this.account,
    required this.signers,
    required this.localNameFor,
    required this.colors,
    required this.text,
    required this.l10n,
  });

  final MultisigAccount account;
  final List<String> signers;
  final String? Function(String accountId) localNameFor;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.multisigCreateSignersLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 8),
          Text(l10n.multisigCreateSignersSubtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: 8),
          ...signers.map(
            (signerId) => MultisigSignerListTile(
              accountId: signerId,
              displayName: localNameFor(signerId),
              isCreator: account.creator != null && signerId == account.creator,
              creatorLabel: l10n.multisigSignerCreatorLabel,
              isYou: signerId == account.myMemberAccountId,
              youLabel: l10n.multisigYouLabel,
              colors: colors,
              text: text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSection extends StatelessWidget {
  const _ThresholdSection({required this.account, required this.colors, required this.text, required this.l10n});

  final MultisigAccount account;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.multisigCreateThresholdLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 12),
          Text(
            l10n.multisigThresholdOf(account.threshold, account.signers.length),
            style: text.mediumTitle?.copyWith(color: colors.accentOrange, fontFamily: AppTextTheme.fontFamilySecondary),
          ),
          const SizedBox(height: 8),
          Text(l10n.multisigAccountMenuDetailsThresholdHint, style: text.detail?.copyWith(color: colors.textTertiary)),
        ],
      ),
    );
  }
}
