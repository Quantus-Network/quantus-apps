import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// "Powered by / near Intents" lockup, tinted with the theme's muted text colour.
class NearIntentsAttribution extends StatelessWidget {
  const NearIntentsAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final colorFilter = ColorFilter.mode(context.colorsV3.textMuted, BlendMode.srcIn);
    return Semantics(
      label: 'Powered by NEAR Intents',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SvgPicture.asset(
            'assets/v2/near_intents_powered_by.svg',
            width: 64.3,
            height: 10.3,
            colorFilter: colorFilter,
          ),
          const SizedBox(height: 6),
          SvgPicture.asset('assets/v2/near_intents_wordmark.svg', width: 90, height: 11, colorFilter: colorFilter),
        ],
      ),
    );
  }
}
