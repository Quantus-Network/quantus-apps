import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class DiscoverMultisigScreen extends ConsumerStatefulWidget {
  const DiscoverMultisigScreen({super.key});

  @override
  ConsumerState<DiscoverMultisigScreen> createState() => _DiscoverMultisigScreenState();
}

class _DiscoverMultisigScreenState extends ConsumerState<DiscoverMultisigScreen> {
  final _addingIds = <String>{};

  Future<void> _addMultisig(MultisigAccount account) async {
    if (_addingIds.contains(account.accountId)) return;

    final l10n = ref.read(l10nProvider);
    final savedCount = ref.read(multisigAccountsProvider).value?.length ?? 0;
    final toAdd = account.copyWith(name: l10n.multisigCreateDefaultName(savedCount + 1));

    setState(() => _addingIds.add(account.accountId));
    try {
      await ref.read(multisigAccountsProvider.notifier).add(toAdd);
      if (!mounted) return;
      context.showSuccessToaster(message: l10n.multisigCreateReadyToast);
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(message: l10n.multisigAddFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _addingIds.remove(account.accountId));
      }
    }
  }

  List<MultisigAccount> _sortedDiscovered(List<MultisigAccount> discovered, Set<String> savedIds) {
    return [...discovered]..sort((a, b) {
      final aAdded = savedIds.contains(a.accountId);
      final bAdded = savedIds.contains(b.accountId);
      if (aAdded == bAdded) return 0;
      return aAdded ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final discoveredAsync = ref.watch(discoveredMultisigsProvider);
    final savedIds = (ref.watch(multisigAccountsProvider).value ?? []).map((a) => a.accountId).toSet();

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigDiscoverTitle),
      mainContent: discoveredAsync.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Skeleton(height: 14, width: 160),
            SizedBox(height: 8),
            Skeleton(height: 12),
            SizedBox(height: 24),
            Skeleton(height: 72),
            SizedBox(height: 12),
            Skeleton(height: 72),
          ],
        ),
        error: (error, _) => _DiscoverError(
          message: l10n.multisigAddDiscoverFailed(error.toString()),
          retryLabel: l10n.homeActivityRetry,
          onRetry: () => ref.invalidate(discoveredMultisigsProvider),
          colors: colors,
          text: text,
        ),
        data: (discovered) {
          final sorted = _sortedDiscovered(discovered, savedIds);
          if (sorted.isEmpty) {
            return Center(
              child: Text(
                l10n.multisigAddNoneFound,
                style: text.smallParagraph?.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.multisigAddDiscoveredTitle, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
              const SizedBox(height: 8),
              Text(l10n.multisigAddDiscoveredSubtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
              const SizedBox(height: 24),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final account = sorted[index];
                  final isAdded = savedIds.contains(account.accountId);
                  final isAdding = _addingIds.contains(account.accountId);

                  return _DiscoverMultisigRow(
                    key: ValueKey(account.accountId),
                    account: account,
                    isAdded: isAdded,
                    isAdding: isAdding,
                    addLabel: l10n.multisigAddButton,
                    addedLabel: l10n.multisigAddedButton,
                    thresholdLabel: l10n.multisigThresholdOf(account.threshold, account.signers.length),
                    colors: colors,
                    text: text,
                    onAdd: () => _addMultisig(account),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiscoverError extends StatelessWidget {
  const _DiscoverError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    required this.colors,
    required this.text,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final AppColorsV2 colors;
  final AppTextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: text.detail?.copyWith(color: colors.textError)),
        const SizedBox(height: 16),
        QuantusButton.simple(label: retryLabel, variant: ButtonVariant.secondary, onTap: onRetry),
      ],
    );
  }
}

class _DiscoverMultisigRow extends ConsumerStatefulWidget {
  const _DiscoverMultisigRow({
    super.key,
    required this.account,
    required this.isAdded,
    required this.isAdding,
    required this.addLabel,
    required this.addedLabel,
    required this.thresholdLabel,
    required this.colors,
    required this.text,
    required this.onAdd,
  });

  final MultisigAccount account;
  final bool isAdded;
  final bool isAdding;
  final String addLabel;
  final String addedLabel;
  final String thresholdLabel;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final VoidCallback onAdd;

  @override
  ConsumerState<_DiscoverMultisigRow> createState() => _DiscoverMultisigRowState();
}

class _DiscoverMultisigRowState extends ConsumerState<_DiscoverMultisigRow> {
  String? _checksum;

  @override
  void initState() {
    super.initState();

    ref
        .read(humanReadableChecksumServiceProvider)
        .getHumanReadableName(widget.account.accountId)
        .then((name) {
          if (mounted) setState(() => _checksum = name);
        })
        .catchError((Object e) {
          quantusDebugPrint('DiscoverMultisigRow: checksum lookup error: $e');
          if (mounted) setState(() => _checksum = 'Error getting checksum');
        });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final address = AddressFormattingService.formatAddress(widget.account.accountId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: widget.colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _checksum ?? l10n.commonLoading,
                  style: widget.text.detail?.copyWith(color: context.colors.checksum),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: widget.text.smallParagraph?.copyWith(
                    color: widget.colors.textPrimary,
                    fontFamily: AppTextTheme.fontFamilySecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(widget.thresholdLabel, style: widget.text.detail?.copyWith(color: widget.colors.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          QuantusButton.simple(
            label: widget.isAdded ? widget.addedLabel : widget.addLabel,
            variant: widget.isAdded ? ButtonVariant.secondary : ButtonVariant.primary,
            isDisabled: widget.isAdded,
            isLoading: widget.isAdding,
            onTap: widget.isAdded ? null : widget.onAdd,
            width: null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ],
      ),
    );
  }
}
