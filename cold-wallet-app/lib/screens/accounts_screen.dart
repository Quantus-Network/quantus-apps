import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/account_avatar.dart';
import 'package:quantus_cold_wallet/components/anchored_menu.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Accounts'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            for (final entry in addresses.entries) _AccountRow(address: entry.key, account: entry.value),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Add Account',
          padding: coldButtonPadding,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen())),
        ),
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  final String address;
  final ColdAccount account;

  const _AccountRow({required this.address, required this.account});

  void _showKey(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ShowKeyScreen(address: address)));

  void _openMenu(BuildContext context, BuildContext anchor, WidgetRef ref) {
    showAnchoredMenu(
      context,
      anchor: anchor,
      width: 234,
      groups: [
        [AnchoredMenuItem(label: 'Show address', onTap: () => _showKey(context)), renameMenuItem(context, account)],
        [disconnectMenuItem(context, ref, account)],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showKey(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: context.radiusV3.mdBorder,
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            AccountAvatar(label: account.label),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.label, style: text.headingRow.copyWith(color: colors.textContent)),
                  const SizedBox(height: 6),
                  Text(shortAddress(address), style: text.dataAddress.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
            Builder(builder: (anchor) => KebabButton(onTap: () => _openMenu(context, anchor, ref))),
          ],
        ),
      ),
    );
  }
}
