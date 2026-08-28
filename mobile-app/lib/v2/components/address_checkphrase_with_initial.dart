import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';

class AddressCheckphraseWithInitial extends StatelessWidget {
  final String recipientChecksum;
  final String recipientAddress;
  final bool showFullAddress;

  const AddressCheckphraseWithInitial({
    super.key,
    required this.recipientChecksum,
    required this.recipientAddress,
    this.showFullAddress = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final addressStyle = showFullAddress ? text.dataAddressLarge : text.dataAddress;
    final displayAddress = showFullAddress
        ? recipientAddress.trim()
        : AddressFormattingService.formatAddress(recipientAddress.trim());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AccountBadge(name: recipientChecksum.replaceAll('-', ' ')),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipientChecksum,
                style: text.body.copyWith(color: colors.semanticLilac),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(displayAddress, style: addressStyle.copyWith(color: colors.textContent), softWrap: true),
            ],
          ),
        ),
      ],
    );
  }
}
