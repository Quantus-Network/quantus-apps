import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TokenIcon extends StatelessWidget {
  static const _quantusAsset = 'assets/v2/token_qtc.svg';

  final SwapToken token;
  final double size;
  final double networkBadgeSize;

  const TokenIcon({super.key, required this.token, this.size = 31, this.networkBadgeSize = 12});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final iconUrl = token.iconUrl;
    final networkIconUrl = token.networkIconUrl;

    if (token.isQuantus) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.18),
        decoration: BoxDecoration(color: colors.bgVoid, shape: BoxShape.circle),
        child: SvgPicture.asset(_quantusAsset),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: iconUrl != null
                  ? Image.network(iconUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallback(token, colors, text))
                  : _fallback(token, colors, text),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: SizedBox(
              width: networkBadgeSize,
              height: networkBadgeSize,
              child: ClipOval(
                child: networkIconUrl != null
                    ? Image.network(
                        networkIconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _networkFallback(token, colors, text),
                      )
                    : _networkFallback(token, colors, text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(SwapToken token, AppColorsV3 colors, AppTextThemeV3 text) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface2,
        shape: BoxShape.circle,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Center(
        child: FittedBox(
          child: Text(
            token.symbol.isNotEmpty ? token.symbol.substring(0, 1) : '?',
            style: text.labelMonogram.copyWith(color: colors.textContent),
          ),
        ),
      ),
    );
  }

  Widget _networkFallback(SwapToken token, AppColorsV3 colors, AppTextThemeV3 text) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bgVoid,
        shape: BoxShape.circle,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Center(
        child: FittedBox(
          child: Text(
            token.network.isNotEmpty ? token.network.substring(0, 1) : '?',
            style: text.labelMonogram.copyWith(color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}
