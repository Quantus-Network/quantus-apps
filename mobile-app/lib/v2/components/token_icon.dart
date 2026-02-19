import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class TokenIcon extends StatelessWidget {
  final SwapToken token;
  final double size;
  final double networkBadgeSize;

  const TokenIcon({super.key, required this.token, this.size = 31, this.networkBadgeSize = 12});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final swapService = SwapService();
    final iconUrl = token.iconUrl ?? swapService.getTokenIconUrl(token);
    final networkIconUrl = token.networkIconUrl ?? swapService.getNetworkIconUrl(token);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: iconUrl != null
                  ? Image.network(
                      iconUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(context, token, colors, text),
                    )
                  : _fallback(context, token, colors, text),
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
                        errorBuilder: (_, _, _) => _networkFallback(context, token, colors, text),
                      )
                    : _networkFallback(context, token, colors, text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context, SwapToken token, AppColorsV2 colors, AppTextTheme text) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F86E8),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF71B5FF), width: 1.4),
      ),
      child: Center(
        child: Text(
          token.symbol.isNotEmpty ? token.symbol.substring(0, 1) : '?',
          style: text.tiny?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _networkFallback(BuildContext context, SwapToken token, AppColorsV2 colors, AppTextTheme text) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF3D3D3D)),
      ),
      child: Center(
        child: Text(
          token.network.isNotEmpty ? token.network.substring(0, 1) : '?',
          style: text.tiny?.copyWith(
            color: colors.textPrimary,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
