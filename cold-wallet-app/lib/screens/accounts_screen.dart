import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final addresses = ref.watch(addressesProvider);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Accounts'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Scan an account with your Quantus hot wallet to add it there.',
              style: text.smallParagraph?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final entry in addresses.entries)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ShowKeyScreen(address: entry.key))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderButton),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(entry.value.label, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
                      Text(entry.value.derivationPath, style: text.detail?.copyWith(color: colors.textMuted)),
                      AddressWithCheckphrase(label: 'Address', address: entry.key),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Add account',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen())),
        ),
      ),
    );
  }
}
