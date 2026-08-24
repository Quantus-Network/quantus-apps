import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';

/// Picks which local signer account should approve a multisig proposal.
///
/// Returns the selected [Account], or `null` if the sheet is dismissed.
Future<Account?> showMultisigSignerPickerSheet(BuildContext context, {required List<Account> accounts}) {
  assert(accounts.isNotEmpty, 'Signer picker requires at least one account');
  return BottomSheetContainer.show<Account>(context, builder: (_) => _MultisigSignerPickerSheet(accounts: accounts));
}

class _MultisigSignerPickerSheet extends ConsumerWidget {
  final List<Account> accounts;

  const _MultisigSignerPickerSheet({required this.accounts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return BottomSheetContainer(
      title: l10n.multisigSignerPickerTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.multisigSignerPickerBody, style: text.bodyLarge.copyWith(color: colors.textContent)),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const MenuDivider(),
              itemBuilder: (_, i) => _accountItem(context, accounts[i], colors, text),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _accountItem(BuildContext context, Account account, AppColorsV3 colors, AppTextThemeV3 text) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, account),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            AccountBadge.account(account: account, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: text.amountRow.copyWith(color: colors.textContent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AddressFormattingService.formatAddress(account.accountId),
                    style: text.dataAddress.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            QuantusIcon(QuantusIcons.chevronRight, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
