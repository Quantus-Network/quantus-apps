import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

class ShowKeyScreen extends ConsumerWidget {
  const ShowKeyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final address = ref.watch(addressProvider);
    final checkphrase = ref.watch(checkphraseProvider);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Show Key'),
      mainContent: address == null
          ? const Center(child: Loader(size: 24))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Scan with your Quantus hot wallet to add this account.',
                    style: text.body.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Center(child: QuantusQr(accountId: address)),
                  const SizedBox(height: 24),
                  checkphrase.when(
                    data: (phrase) => Text(
                      phrase,
                      style: text.headingRow.copyWith(color: colors.semanticLilac),
                      textAlign: TextAlign.center,
                    ),
                    loading: () => const Loader(size: 16),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
                    child: Text(
                      address,
                      style: text.dataAddressLarge.copyWith(color: colors.textContent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
