import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Full-screen pairing code (Figma Cold Wallet / Enlarged). Any tap closes it.
class EnlargedQrScreen extends StatelessWidget {
  static const double qrSize = 330;

  final String address;
  final String label;

  const EnlargedQrScreen({super.key, required this.address, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: ScaffoldBase(
        mainContent: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: text.titleScreen.copyWith(color: colors.textContent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: qrSize,
                height: qrSize,
                child: FittedBox(child: QuantusQr(accountId: address)),
              ),
              const SizedBox(height: 24),
              Text('Tap anywhere to close', style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
