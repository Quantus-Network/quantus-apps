import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class QuantusQr extends StatelessWidget {
  final String accountId;
  final BorderRadius borderRadius;

  const QuantusQr({
    super.key,
    required this.accountId,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    final qrSize = 267.0;
    final qrLogoSize = 64.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colorsV3.borderHairline, width: 1),
        borderRadius: borderRadius,
      ),
      width: qrSize,
      height: qrSize,
      child: QrImageView(
        data: accountId,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        embeddedImage: const AssetImage('assets/v2/uppercase_q_black_bg.png', package: 'quantus_sdk'),
        embeddedImageStyle: QrEmbeddedImageStyle(size: Size(qrLogoSize, qrLogoSize)),
        version: QrVersions.auto,
        size: qrSize,
        padding: const EdgeInsets.all(16),
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
      ),
    );
  }
}
