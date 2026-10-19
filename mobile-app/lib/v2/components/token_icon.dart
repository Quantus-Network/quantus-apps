import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

class TokenIcon extends ConsumerWidget {
  static const _quantusAsset = 'assets/v2/token_qtc.svg';

  final SwapToken token;
  final double size;

  /// Only the network's logo, round, as in the middle of a deposit QR.
  final bool networkOnly;

  const TokenIcon({super.key, required this.token, this.size = 32}) : networkOnly = false;

  const TokenIcon.network({super.key, required this.token, this.size = 32}) : networkOnly = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final networkUrl = token.networkImageUrl;
    final networkLogo = networkUrl == null ? null : ref.watch(swapImageProvider(networkUrl)).value;
    final networkMonogram = _networkMonogram(token, colors, text);
    final network = networkLogo == null
        ? networkMonogram
        : Container(
            decoration: BoxDecoration(
              color: colors.textWhite,
              shape: BoxShape.circle,
              border: Border.all(color: colors.bgVoid),
            ),
            child: ClipOval(child: _logo(networkLogo, networkMonogram)),
          );
    if (networkOnly) return SizedBox(width: size, height: size, child: network);

    if (token.isQuantus) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.18),
        decoration: BoxDecoration(color: colors.bgVoid, shape: BoxShape.circle),
        child: SvgPicture.asset(_quantusAsset),
      );
    }

    final icon = ref.watch(swapTokenIconProvider(token)).value;
    final monogram = _monogram(token, colors, text);
    final badgeSize = size / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: icon == null ? monogram : ClipOval(child: _logo(icon, monogram))),
          Positioned(
            right: -2,
            bottom: -2,
            child: SizedBox(width: badgeSize, height: badgeSize, child: network),
          ),
        ],
      ),
    );
  }

  Widget _logo(SwapTokenIcon icon, Widget fallback) => icon.isSvg
      ? SvgPicture.memory(icon.bytes, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback)
      : Image.memory(icon.bytes, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);

  Widget _monogram(SwapToken token, AppColorsV3 colors, AppTextThemeV3 text) {
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

  Widget _networkMonogram(SwapToken token, AppColorsV3 colors, AppTextThemeV3 text) {
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
