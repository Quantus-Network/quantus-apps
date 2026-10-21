import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';

class AddressCheckphraseWithInitial extends StatelessWidget {
  final String address;
  final bool showFullAddress;

  const AddressCheckphraseWithInitial({super.key, required this.address, this.showFullAddress = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final addressStyle = showFullAddress ? text.dataAddressLarge : text.dataAddress;
    final trimmed = address.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AccountBadge.checkphrase(address: trimmed),
        const SizedBox(width: 14),
        Expanded(
          child: AddressCheckphrase(
            address: trimmed,
            displayAddress: showFullAddress ? null : AddressFormattingService.formatAddress(trimmed),
            addressStyle: addressStyle.copyWith(color: colors.textContent),
          ),
        ),
      ],
    );
  }
}
