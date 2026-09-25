import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Icon-over-label action tile from the app design (home Receive / Send / Swap,
/// POS Charge). Not a design-system Button type: gradient fill, hairline border,
/// 20/8 padding. Rows use a 20 gap for two cards and 15 for three. The label
/// never wraps; it only scales down if it still doesn't fit (large system font).
class ActionCard extends StatelessWidget {
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool isDisabled;

  const ActionCard({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.mdBorder;
    final labelStyle = context.themeTextV3.bodyLarge.copyWith(color: colors.textWhite.useOpacity(0.8));
    return Opacity(
      opacity: isDisabled ? 0.4 : 1,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.bgCardGradientTop, colors.bgCardGradientBottom],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: colors.borderHairline),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(colors.accentFlare, BlendMode.srcIn),
              ),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) * labelStyle.height!,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1, style: labelStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
