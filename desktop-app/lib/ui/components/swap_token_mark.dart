import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/swap_providers.dart';

/// A swap token's mark: its logo, round, with its chain's at the lower
/// right; or, with [SwapTokenMark.network], its chain's alone. Until a logo
/// has loaded, and for one that cannot be had, it is the first letter of the
/// token's symbol or of its chain. QTC has the app's own mark, and no chain
/// beside it.
class SwapTokenMark extends ConsumerWidget {
  const SwapTokenMark({super.key, required this.token, this.size = 20}) : networkOnly = false;

  /// Only the chain's mark, as a deposit's code holds it in its middle.
  const SwapTokenMark.network({super.key, required this.token, this.size = 20}) : networkOnly = true;

  final SwapToken token;
  final double size;
  final bool networkOnly;

  /// QTC's mark, the phone's.
  static const quantusAsset = 'assets/token_qtc.svg';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final networkUrl = token.networkImageUrl;
    final networkLogo = networkUrl == null ? null : ref.watch(swapImageProvider(networkUrl)).value;
    final networkLetter = _letter(context, token.network, ground: colors.bgVoid, ink: colors.textMuted);
    final network = networkLogo == null
        ? networkLetter
        // On white: a logo with clear parts would show the panel through.
        : Container(
            decoration: BoxDecoration(
              color: colors.textWhite,
              shape: BoxShape.circle,
              border: Border.all(color: colors.bgVoid),
            ),
            child: ClipOval(child: _logo(networkLogo, networkLetter)),
          );
    if (networkOnly) return SizedBox.square(dimension: size, child: network);

    if (token.isQuantus) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.18),
        decoration: BoxDecoration(color: colors.bgVoid, shape: BoxShape.circle),
        child: SvgPicture.asset(quantusAsset),
      );
    }

    final logo = ref.watch(swapTokenIconProvider(token)).value;
    final letter = _letter(context, token.symbol, ground: colors.bgSurface2, ink: colors.textContent);
    final badge = size / 2;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: logo == null ? letter : ClipOval(child: _logo(logo, letter))),
          Positioned(
            right: -2,
            bottom: -2,
            child: SizedBox.square(dimension: badge, child: network),
          ),
        ],
      ),
    );
  }

  Widget _logo(SwapTokenIcon icon, Widget fallback) => icon.isSvg
      ? SvgPicture.memory(icon.bytes, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback)
      : Image.memory(icon.bytes, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);

  /// The first letter of [name] on a disc, where there is no logo.
  Widget _letter(BuildContext context, String name, {required Color ground, required Color ink}) {
    return Container(
      decoration: BoxDecoration(
        color: ground,
        shape: BoxShape.circle,
        border: Border.all(color: context.colorsV3.borderHairline),
      ),
      child: Center(
        child: FittedBox(
          child: Text(
            name.isNotEmpty ? name.substring(0, 1) : '?',
            style: context.themeTextV3.labelMonogram.copyWith(color: ink),
          ),
        ),
      ),
    );
  }
}
