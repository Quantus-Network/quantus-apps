import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
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
              style: text.body.copyWith(color: colors.textMuted),
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
                    color: colors.bgSurface,
                    borderRadius: context.radiusV3.mdBorder,
                    border: Border.all(color: colors.borderHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(entry.value.label, style: text.headingRow.copyWith(color: colors.textContent)),
                      Text(entry.value.derivationPath, style: text.caption.copyWith(color: colors.textMuted)),
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
