import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/ur_qr_panel.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';

/// The screen shown once a transaction is signed: [signed] as a UR QR for
/// the hot wallet to scan, and a Done button back to home.
class SignatureQrView extends StatelessWidget {
  final Uint8List signed;
  final String instruction;

  const SignatureQrView({super.key, required this.signed, required this.instruction});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Signature', showBackButton: false),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(
              instruction,
              style: text.body.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            UrQrPanel(payload: UrPayload(signed)),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Done', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ),
    );
  }
}
