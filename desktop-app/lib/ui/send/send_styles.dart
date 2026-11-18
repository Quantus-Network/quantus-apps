import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The text styles the Send sheet's steps share.
extension SendStyles on BuildContext {
  /// A small label drawn in capitals.
  TextStyle sendCaps({Color? color, double spacing = 1.4}) =>
      themeTextV3.dataAddress.copyWith(height: 1, letterSpacing: spacing, color: color ?? colorsV3.textMuted2);

  /// An address or a checkphrase.
  TextStyle sendMono(Color color) =>
      themeTextV3.dataAddressLarge.copyWith(height: 1.3, letterSpacing: 0.3, color: color);

  /// A line of plain text, quiet unless given a [color].
  TextStyle sendBody({Color? color}) => themeTextV3.body.copyWith(color: color ?? colorsV3.textMuted);
}
