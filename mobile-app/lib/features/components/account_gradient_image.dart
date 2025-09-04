import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/utils/color_generator_engine.dart';

class AccountGradientImage extends StatelessWidget {
  final dynamic accountId;
  final dynamic width;
  final dynamic height;

  const AccountGradientImage({
    super.key,
    required this.accountId,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: buildAccountGradient(
          accountId,
          engine: ColorEngine.oklch,
          hueStrategy: HueStrategy.golden,
          options: quantusGradientOptions,
        ).linear,
      ),
    );
  }
}
