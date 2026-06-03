import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/multisig_badge.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AddMultisigScreen extends ConsumerStatefulWidget {
  const AddMultisigScreen({super.key});

  @override
  ConsumerState<AddMultisigScreen> createState() => _AddMultisigScreenState();
}

class _AddMultisigScreenState extends ConsumerState<AddMultisigScreen> {
  final _addressController = TextEditingController();
  final _addressFocus = FocusNode();
  bool _isAddingFromManual = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  bool get _isManualValid {
    final text = _addressController.text.trim();
    if (text.isEmpty) return false;
    final substrate = ref.read(substrateServiceProvider);
    return substrate.isValidSS58Address(text);
  }

  Future<void> _addFromManualEntry() async {
    final l10n = ref.read(l10nProvider);
    final address = _addressController.text.trim();
    if (!_isManualValid) return;
    setState(() {
      _isAddingFromManual = true;
      _error = null;
    });
    try {
      final ids = (ref.read(accountsProvider).value ?? const <Account>[]).map((a) => a.accountId).toList();
      final msig = await ref.read(multisigServiceProvider).lookupByAddress(address, ids);
      if (msig == null) {
        throw Exception('No multisig found at this address');
      }
      await ref.read(multisigAccountsProvider.notifier).add(msig);
      await ref.read(activeAccountProvider.notifier).setActiveAccount(MultisigDisplayAccount(msig));
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e, st) {
      debugPrint('add multisig from manual error: $e $st');
      if (!mounted) return;
      setState(() {
        _error = l10n.multisigAddFailed(e.toString());
        _isAddingFromManual = false;
      });
    }
  }

  Future<void> _addDiscovered(MultisigAccount msig) async {
    final l10n = ref.read(l10nProvider);
    setState(() => _error = null);
    try {
      await ref.read(multisigAccountsProvider.notifier).add(msig);
      await ref.read(activeAccountProvider.notifier).setActiveAccount(MultisigDisplayAccount(msig));
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e, st) {
      debugPrint('add discovered multisig error: $e $st');
      if (!mounted) return;
      setState(() => _error = l10n.multisigAddFailed(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final discoveredAsync = ref.watch(discoveredMultisigsProvider);
    final alreadyAdded = (ref.watch(multisigAccountsProvider).value ?? const <MultisigAccount>[])
        .map((m) => m.accountId)
        .toSet();

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigAddTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.multisigAddPasteAddressSection, style: text.sendSectionLabel?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 12),
          _buildAddressField(l10n, colors, text),
          const SizedBox(height: 28),
          DottedBorder(
            dashLength: 3,
            gapLength: 5,
            color: colors.borderButton.useOpacity(0.5),
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 28),
          Text(l10n.multisigAddDiscoveredTitle, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text(l10n.multisigAddDiscoveredSubtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: 20),
          Expanded(child: _buildDiscoveredList(l10n, discoveredAsync, alreadyAdded, colors, text)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: text.detail?.copyWith(color: colors.textError)),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.multisigAddFromAddressButton,
          variant: ButtonVariant.primary,
          isDisabled: !_isManualValid || _isAddingFromManual,
          isLoading: _isAddingFromManual,
          onTap: _addFromManualEntry,
        ),
      ),
    );
  }

  Widget _buildAddressField(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.account_tree_outlined, size: 16, color: colors.textLabel),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _addressController,
              focusNode: _addressFocus,
              autocorrect: false,
              enableSuggestions: false,
              style: text.smallParagraph?.copyWith(color: colors.textPrimary),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: l10n.multisigAddAddressHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredList(
    AppLocalizations l10n,
    AsyncValue<List<MultisigAccount>> discoveredAsync,
    Set<String> alreadyAdded,
    AppColorsV2 colors,
    AppTextTheme text,
  ) {
    return discoveredAsync.when(
      loading: () => const Center(child: Loader()),
      error: (e, _) => Center(
        child: Text(
          l10n.multisigAddDiscoverFailed(e.toString()),
          style: text.detail?.copyWith(color: colors.textError),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(l10n.multisigAddNoneFound, style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: colors.txItemSeparator),
          itemBuilder: (_, i) {
            final msig = items[i];
            final added = alreadyAdded.contains(msig.accountId);
            return _DiscoveredRow(l10n: l10n, msig: msig, added: added, onAdd: () => _addDiscovered(msig));
          },
        );
      },
    );
  }
}

class _DiscoveredRow extends StatelessWidget {
  final AppLocalizations l10n;
  final MultisigAccount msig;
  final bool added;
  final VoidCallback onAdd;

  const _DiscoveredRow({required this.l10n, required this.msig, required this.added, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          MultisigBadge(account: msig),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        msig.name,
                        style: text.paragraph?.copyWith(color: colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    MultisigTag(label: l10n.multisigTag),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AddressFormattingService.formatAddress(msig.accountId),
                  style: text.detail?.copyWith(
                    color: colors.textTertiary,
                    fontFamily: AppTextTheme.fontFamilySecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          QuantusButton.simple(
            label: added ? l10n.multisigAddedButton : l10n.multisigAddButton,
            variant: added ? ButtonVariant.outline : ButtonVariant.secondary,
            isDisabled: added,
            onTap: added ? null : onAdd,
            width: null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ],
      ),
    );
  }
}
