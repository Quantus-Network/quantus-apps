import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';

/// Home pill naming the active account; opens the Accounts screen.
class OpenAccountsManagementButton extends ConsumerWidget {
  const OpenAccountsManagementButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(activeAccountProvider).value?.account.name;
    final colors = context.colorsV3;

    return GestureDetector(
      onTap: () => openAccountsScreen(context),
      child: GlassButtonBase(
        buttonHeight: 44,
        borderRadius: context.radiusV3.pillBorder,
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Center(child: SvgPicture.asset('assets/v2/uppercase_q.svg', width: 20, height: 20)),
            ),
            if (name != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  name,
                  style: context.themeTextV3.headingRow.copyWith(color: colors.textContent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(width: 8),
            QuantusIcon(QuantusIcons.caretUpDown, color: colors.textContent),
          ],
        ),
      ),
    );
  }
}
