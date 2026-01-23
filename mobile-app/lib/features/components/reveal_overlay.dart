import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class RevealOverlay extends StatelessWidget {
  final VoidCallback onReveal;

  const RevealOverlay({super.key, required this.onReveal});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallHeight = constraints.maxHeight < 200;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 21, vertical: isSmallHeight ? 10 : 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSmallHeight) ...[
                Icon(Icons.visibility_off, color: Colors.white, size: context.isTablet ? 60 : 40),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: context.isTablet ? 400 : null,
                child: Text(
                  'This Recovery Phrase provides access to this wallet, '
                  'only reveal if you are in a secure location',
                  textAlign: TextAlign.center,
                  style: context.themeText.smallParagraph?.copyWith(
                    color: context.themeColors.textMuted,
                    fontSize: isSmallHeight ? 12 : null,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: isSmallHeight ? 8 : 12),
              ElevatedButton(
                onPressed: onReveal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.useOpacity(0.25),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(width: 1, color: Colors.white.useOpacity(0.15)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                  minimumSize: const Size(0, 36), // Reduce minimum height
                ),
                child: Text('Reveal', textAlign: TextAlign.center, style: context.themeText.smallParagraph),
              ),
            ],
          ),
        );
      },
    );
  }
}
