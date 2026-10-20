import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/router.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// The current account's name and address, with a menu to switch or add one.
class AccountSwitcher extends ConsumerWidget {
  const AccountSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final l10n = ref.watch(l10nProvider);
    final current = ref.watch(currentAccountProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.bgSurface2),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: context.radiusV3.smBorder)),
      ),
      menuChildren: [
        for (final account in accounts)
          MenuItemButton(
            onPressed: () => ref.read(activeAccountProvider.notifier).setActiveAccount(RegularAccount(account)),
            leadingIcon: Icon(
              account.accountId == current?.accountId ? Icons.check_rounded : Icons.circle_outlined,
              size: 16,
              color: colors.textMuted,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: text.body.copyWith(color: colors.textContent)),
                Text(
                  AddressFormattingService.formatAddress(account.accountId),
                  style: text.dataAddress.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        const Divider(height: 8),
        MenuItemButton(
          onPressed: () => context.go(AppRoutes.addAccount),
          leadingIcon: Icon(Icons.add_rounded, size: 16, color: colors.textMuted),
          child: Text(l10n.navAddAccount, style: text.body.copyWith(color: colors.textContent)),
        ),
      ],
      builder: (context, controller, _) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          borderRadius: context.radiusV3.smBorder,
          hoverColor: colors.bgSurface2,
          splashFactory: NoSplash.splashFactory,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: context.radiusV3.smBorder),
                  child: Text(
                    (current?.name.isNotEmpty ?? false) ? current!.name[0].toUpperCase() : 'Q',
                    style: text.labelMonogram.copyWith(color: colors.accentFlare),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current?.name ?? '',
                        style: text.bodyEmphasis.copyWith(color: colors.textContent),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        current == null ? '' : AddressFormattingService.formatAddress(current.accountId),
                        style: text.dataAddress.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more_rounded, size: 18, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
