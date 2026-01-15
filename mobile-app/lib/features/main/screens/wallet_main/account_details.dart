import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_copy_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/account_tag.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AccountDetails extends StatefulWidget {
  final BaseAccount activeAccount;
  final bool isEntrustedAccount;

  const AccountDetails({super.key, required this.activeAccount, this.isEntrustedAccount = false});

  @override
  State<AccountDetails> createState() => _AccountDetailsState();
}

class _AccountDetailsState extends State<AccountDetails> {
  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();

  @override
  void initState() {
    super.initState();
  }

  void _showActionSheet() {
    showAccountCopyActionSheet(context, widget.activeAccount);
  }

  @override
  Widget build(BuildContext context) {
    final checksumFuture = _checksumService.getHumanReadableName(widget.activeAccount.accountId);

    return GestureDetector(
      onTap: _showActionSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: context.themeColors.navbarBg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 2,
          children: [
            if (widget.isEntrustedAccount)
              AccountTag(text: 'Entrusted Account', color: context.themeColors.accountTagEntrusted),
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
                      Container(
                        width: 195,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 1,
                          children: [
                            SizedBox(
                              width: 195,
                              child: Text(widget.activeAccount.name, style: context.themeText.smallParagraph),
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
