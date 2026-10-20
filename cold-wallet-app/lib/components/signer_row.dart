import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/account_avatar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

/// The wallet's own account that signs: its name, its shortened address and
/// its checkphrase. Every other address on the review is shown in full.
class SignerRow extends ConsumerWidget {
  final String label;
  final String address;

  const SignerRow({super.key, required this.label, required this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account =
        ref.watch(addressesProvider)[address] ?? (throw StateError('Signer $address is not in this wallet'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AccountAvatar(label: account.label),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.label, style: text.headingRow.copyWith(color: colors.textContent)),
                    const SizedBox(height: 4),
                    Text(
                      AddressFormattingService.formatAddress(address, prefix: 7, ellipses: '…', postFix: 6),
                      style: text.dataAddressLarge.copyWith(fontWeight: FontWeight.w500, color: colors.textWhite),
                    ),
                    const SizedBox(height: 4),
                    CheckphraseText(address, style: text.body.copyWith(color: colors.semanticLilac)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
