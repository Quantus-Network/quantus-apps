import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A QR of [accountId] with the Quantus mark in the middle, or [logo] on a
/// square of the void colour in its place.
class QuantusQr extends StatelessWidget {
  static const size = 267.0;
  static const _markSize = 64.0;
  static const _logoSquare = 60.0;

  final String accountId;
  final BorderRadius borderRadius;
  final Widget? logo;

  const QuantusQr({
    super.key,
    required this.accountId,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.logo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final logo = this.logo;
    final qr = QrImageView(
      data: accountId,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      embeddedImage: logo == null
          ? const AssetImage('assets/v2/uppercase_q_black_bg.png', package: 'quantus_sdk')
          : null,
      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(_markSize, _markSize)),
      version: QrVersions.auto,
      size: size,
      padding: const EdgeInsets.all(16),
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderHairline, width: 1),
        borderRadius: borderRadius,
      ),
      width: size,
      height: size,
      child: logo == null
          ? qr
          : Stack(
              alignment: Alignment.center,
              children: [
                qr,
                Container(
                  width: _logoSquare,
                  height: _logoSquare,
                  color: colors.bgVoid,
                  alignment: Alignment.center,
                  child: logo,
                ),
              ],
            ),
    );
  }
}
