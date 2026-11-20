import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// An address with its checkphrase under it, at desktop size: the whole
/// address, never shortened, and both in the monospaced face. Wherever this
/// app shows an address it shows it this way.
///
/// The order and the checkphrase's lookup are the shared
/// [AddressCheckphrase]'s; this gives it the desktop's look. [isCompact]
/// sets it a size smaller, as a list's rows and a side panel show it.
class DesktopAddressCheckphrase extends StatelessWidget {
  const DesktopAddressCheckphrase({super.key, required this.address, this.isCompact = false});

  final String address;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final face = isCompact ? context.themeTextV3.dataAddress : context.themeTextV3.dataAddressLarge;
    final style = face.copyWith(height: 1.3, letterSpacing: 0.3);

    return AddressCheckphrase(
      address: address,
      addressStyle: style.copyWith(color: isCompact ? colors.textContent : colors.textWhite),
      checkphraseStyle: style.copyWith(color: colors.semanticLilac),
    );
  }
}
