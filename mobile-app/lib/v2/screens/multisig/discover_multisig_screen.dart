import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';

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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
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
        ),
        data: (discovered) {
          final sorted = _sortedDiscovered(discovered, savedIds);
          if (sorted.isEmpty) {
            return Center(
              child: Text(
                l10n.multisigAddNoneFound,
                style: text.body.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.multisigAddDiscoveredTitle, style: text.labelData.copyWith(color: colors.textMuted)),
                const SizedBox(height: 8),
                Text(l10n.multisigAddDiscoveredSubtitle, style: text.caption.copyWith(color: colors.textMuted)),
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
                      onAdd: () => _addMultisig(account),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiscoverError extends StatelessWidget {
  const _DiscoverError({required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: text.caption.copyWith(color: colors.semanticEmber)),
        const SizedBox(height: 16),
        QuantusButton.simple(label: retryLabel, variant: ButtonVariant.staged, onTap: onRetry),
      ],
    );
  }
}

class _DiscoverMultisigRow extends ConsumerWidget {
  const _DiscoverMultisigRow({
    super.key,
    required this.account,
    required this.isAdded,
    required this.isAdding,
    required this.addLabel,
    required this.addedLabel,
    required this.thresholdLabel,
    required this.onAdd,
  });

  final MultisigAccount account;
  final bool isAdded;
  final bool isAdding;
  final String addLabel;
  final String addedLabel;
  final String thresholdLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AddressCheckphrase(
                  address: account.accountId,
                  displayAddress: AddressFormattingService.formatAddress(account.accountId),
                ),
                const SizedBox(height: 4),
                Text(thresholdLabel, style: text.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          QuantusButton.simple(
            label: isAdded ? addedLabel : addLabel,
            variant: isAdded ? ButtonVariant.staged : ButtonVariant.primary,
            isDisabled: isAdded,
            isLoading: isAdding,
            onTap: isAdded ? null : onAdd,
            width: null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ],
      ),
    );
  }
}
