import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/step_header.dart';
import 'package:quantus_cold_wallet/components/ur_qr_panel.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Step 3 of signing (Figma Cold Wallet / Transmitting): [signed] as an
/// animated UR QR for the phone to scan. This device cannot tell when the
/// phone has every frame, so signing ends when the user taps Done; back
/// returns to the review.
class SignatureQrView extends StatelessWidget {
  final Uint8List signed;

  const SignatureQrView({super.key, required this.signed});

  static Future<void> push(BuildContext context, Uint8List signed) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SignatureQrView(signed: signed)));

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Sign'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepHeader(
              step: 3,
              total: 3,
              title: 'Show the signature',
              subtitle:
                  'Hold your phone up to this screen. The code keeps repeating until your phone has the whole '
                  'signature.',
            ),
            const SizedBox(height: 24),
            UrQrPanel(payload: UrPayload(signed)),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Done',
          padding: coldButtonPadding,
          onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
      ),
    );
  }
}
