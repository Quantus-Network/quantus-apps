import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Address with its checkphrase underneath: the one place that fixes the order.
class AddressCheckphrase extends StatelessWidget {
  final String address;
  final String? checkphrase;

  /// Whether the address is shown in its short form.
  final bool shorten;
  final TextStyle? addressStyle;
  final TextStyle? checkphraseStyle;

  /// Colour of the checkphrase in the default style; lilac unless set.
  final Color? checkphraseColor;
  final TextAlign textAlign;

  /// Shown in place of the checkphrase while it is null or empty.
  final Widget? placeholder;

  /// Badges rendered inline after the address.
  final List<Widget> badges;

  const AddressCheckphrase({
    super.key,
    required this.address,
    required this.checkphrase,
    this.shorten = false,
    this.addressStyle,
    this.checkphraseStyle,
    this.checkphraseColor,
    this.textAlign = TextAlign.start,
    this.placeholder,
    this.badges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;
    final phrase = checkphrase;
    final shown = shorten ? AddressFormattingService.formatAddress(address) : address;
    final addressText = Text(
      shown,
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
        if (phrase != null && phrase.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            phrase,
            style: checkphraseStyle ?? text.body.copyWith(color: checkphraseColor ?? colors.semanticLilac),
            textAlign: textAlign,
          ),
        ] else if (placeholder != null) ...[
          const SizedBox(height: 4),
          placeholder!,
        ],
      ],
    );
  }

  CrossAxisAlignment get _crossAxis => switch (textAlign) {
    TextAlign.center => CrossAxisAlignment.center,
    TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.start,
  };
}
