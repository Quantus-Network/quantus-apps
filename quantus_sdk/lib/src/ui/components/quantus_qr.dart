import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class QuantusQr extends StatelessWidget {
  final String accountId;
  final double size;

  const QuantusQr({super.key, required this.accountId, this.size = 267});

  @override
  Widget build(BuildContext context) {
    final logoSize = size * 64 / 267;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colorsV3.borderHairline, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      width: size,
      height: size,
      child: QrImageView(
        data: accountId,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        embeddedImage: const AssetImage('assets/v2/uppercase_q_black_bg.png', package: 'quantus_sdk'),
        embeddedImageStyle: QrEmbeddedImageStyle(size: Size(logoSize, logoSize)),
        version: QrVersions.auto,
        size: size,
        padding: const EdgeInsets.all(16),
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
      ),
    );
  }
}
