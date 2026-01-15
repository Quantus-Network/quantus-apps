import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_copy_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/account_tag.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AccountDetails extends ConsumerWidget {
  final BaseAccount activeAccount;
  final bool isEntrustedAccount;

  const AccountDetails({super.key, required this.activeAccount, this.isEntrustedAccount = false});

  void _showActionSheet(BuildContext context, BaseAccount account) {
    showAccountCopyActionSheet(context, account);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checksumFuture = HumanReadableChecksumService().getHumanReadableName(activeAccount.accountId);
    final isHighSecurityAsync = activeAccount is Account
        ? ref.watch(isHighSecurityProvider(activeAccount as Account))
        : null;
    final isHighSecurity = isHighSecurityAsync?.value ?? false;

    return GestureDetector(
      onTap: () => _showActionSheet(context, activeAccount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: context.themeColors.navbarBg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 2,
          children: [
            if (isEntrustedAccount)
              AccountTag(text: 'Entrusted Account', color: context.themeColors.accountTagEntrusted),
            if (isHighSecurity && !isEntrustedAccount)
              AccountTag(text: 'High Security', color: context.themeColors.accountTagEntrusted),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 23,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 12,
                    children: [
                      Image.asset('assets/active_dot.png', width: context.isTablet ? 28 : 20),
                      SizedBox(
                        width: 195,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 1,
                          children: [
                            SizedBox(
                              width: 195,
                              child: Text(activeAccount.name, style: context.themeText.smallParagraph),
                            ),
                            FutureBuilder(
                              future: checksumFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Text('Failed getting checksum', style: context.themeText.smallParagraph);
                                }

                                if (snapshot.hasData) {
                                  return Text(
                                    snapshot.data!,
                                    style: context.themeText.tiny?.copyWith(color: context.themeColors.checksum),
                                  );
                                }

                                return Text('Loading checksum...', style: context.themeText.smallParagraph);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: context.themeColors.textPrimary,
                    size: context.isTablet ? 18 : 12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
