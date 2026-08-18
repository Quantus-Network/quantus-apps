import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/titled_sheet.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';
import 'package:quantus_cold_wallet/widgets/derivation_field.dart';

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
        child: QuantusButton.simple(label: 'Add account', onTap: () => _addAccount(context, ref)),
      ),
    );
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    ColdAccount? chosen;
    await showTitledSheet(
      context,
      title: 'Add account',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DerivationField(onChanged: (a) => setState(() => chosen = a)),
            const SizedBox(height: 20),
            QuantusButton.simple(
              label: 'Add',
              isDisabled: chosen == null,
              onTap: chosen == null ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    final account = chosen;
    if (account == null || !context.mounted) return;
    try {
      await ref.read(walletControllerProvider.notifier).addAccount(account);
    } catch (e) {
      debugPrint('Add account failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add the account: $e')));
      }
    }
  }
}
