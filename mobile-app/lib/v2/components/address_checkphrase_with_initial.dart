import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AddressCheckphraseWithInitial extends StatelessWidget {
  final String recipientChecksum;
  final String recipientAddress;

  const AddressCheckphraseWithInitial({super.key, required this.recipientChecksum, required this.recipientAddress});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    final avatarSize = 40.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(20)),
          child: Text(
            getAccountBadgeInitials(recipientChecksum, separator: '-'),
            style: text.transactionDetailRowValue?.copyWith(color: colors.textLabel),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipientChecksum,
                style: text.smallParagraph?.copyWith(color: colors.checksum, height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                AddressFormattingService.formatAddress(recipientAddress.trim()),
                style: text.transactionDetailRowValue?.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
