import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/loader.dart';
import 'package:quantus_cold_wallet/components/quantus_qr.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class ShowKeyScreen extends ConsumerWidget {
  const ShowKeyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
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
                    style: text.smallParagraph?.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Center(child: QuantusQr(accountId: address)),
                  const SizedBox(height: 24),
                  checkphrase.when(
                    data: (phrase) => Text(
                      phrase,
                      style: text.smallTitle?.copyWith(color: colors.checksum),
                      textAlign: TextAlign.center,
                    ),
                    loading: () => const Loader(size: 16),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      address,
                      style: text.detail?.copyWith(
                        color: colors.textPrimary,
                        fontFamily: AppTextTheme.fontFamilySecondary,
                      ),
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
