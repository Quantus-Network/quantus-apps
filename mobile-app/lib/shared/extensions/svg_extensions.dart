import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

extension SvgPictureExtensions on SvgPicture {
  static SvgPicture assetWithColor(String assetName, {double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      assetName,
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }
}
