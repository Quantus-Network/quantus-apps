import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Address with its checkphrase underneath: the one place that fixes the order.
class AddressCheckphrase extends StatelessWidget {
  /// The full address; the checkphrase is derived from it.
  final String address;

  /// What is drawn for the address when it should not appear in full.
  final String? displayAddress;
  final TextStyle? addressStyle;
  final TextStyle? checkphraseStyle;
  final TextAlign textAlign;

  /// Replaces the checkphrase line, e.g. with the name of a known account.
  final Widget? secondary;

  /// Badges rendered inline after the address.
  final List<Widget> badges;

  const AddressCheckphrase({
    super.key,
    required this.address,
    this.displayAddress,
    this.addressStyle,
    this.checkphraseStyle,
    this.textAlign = TextAlign.start,
    this.secondary,
    this.badges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;
    final addressText = Text(
      displayAddress ?? address,
      style: addressStyle ?? text.dataAddress.copyWith(color: colors.textContent),
      textAlign: textAlign,
    );

    return Column(
      crossAxisAlignment: _crossAxis,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badges.isEmpty)
          addressText
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: addressText),
              for (final badge in badges) ...[const SizedBox(width: 8), badge],
            ],
          ),
        const SizedBox(height: 4),
        secondary ??
            CheckphraseText(
              address,
              style: checkphraseStyle ?? text.body.copyWith(color: colors.semanticLilac),
              textAlign: textAlign,
            ),
      ],
    );
  }

  CrossAxisAlignment get _crossAxis => switch (textAlign) {
    TextAlign.center => CrossAxisAlignment.center,
    TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.start,
  };
}
