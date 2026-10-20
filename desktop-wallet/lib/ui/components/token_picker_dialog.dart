import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/providers/swap_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

Future<SwapToken?> showTokenPickerDialog(BuildContext context) => showDialog<SwapToken>(
  context: context,
  builder: (_) => const Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: EdgeInsets.all(48),
    child: TokenPickerDialog(),
  ),
);

class TokenPickerDialog extends ConsumerStatefulWidget {
  const TokenPickerDialog({super.key});

  @override
  ConsumerState<TokenPickerDialog> createState() => _TokenPickerDialogState();
}

class _TokenPickerDialogState extends ConsumerState<TokenPickerDialog> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final tokens = ref.watch(swapTokensProvider);
    return QuantusDialogFrame(
      maxWidth: 480,
      child: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.swapTokenPickerTitle, style: text.titleScreen.copyWith(color: colors.textContent)),
                ),
                QuantusIconButton.ghost(
                  icon: Icons.close_rounded,
                  size: IconButtonSize.small,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            QuantusTextField(
              controller: _query,
              hint: l10n.swapTokenSearchHint,
              showClearButton: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: tokens.when(
                loading: () => const Center(child: Loader(size: 24)),
                error: (e, _) => Center(
                  child: Text(
                    l10n.swapTokensError(describeSwapError(e)),
                    style: text.caption.copyWith(color: colors.semanticEmber),
                  ),
                ),
                data: (list) {
                  final matches = SwapService.search(list.where((t) => !t.isQuantus).toList(), _query.text);
                  if (matches.isEmpty) {
                    return Center(
                      child: Text(l10n.swapTokenNoMatch, style: text.caption.copyWith(color: colors.textMuted)),
                    );
                  }
                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, i) =>
                        _TokenRow(token: matches[i], onTap: () => Navigator.pop(context, matches[i])),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenRow extends ConsumerWidget {
  final SwapToken token;
  final VoidCallback onTap;

  const _TokenRow({required this.token, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.radiusV3.smBorder,
        hoverColor: colors.bgSurface2,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              TokenLogo(token: token),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(token.symbol, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
                    Text(token.networkName, style: text.caption.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
              if (token.usdPrice > 0)
                Text(
                  FiatCurrency.usd.format(token.usdPrice.toStringAsFixed(2)),
                  style: text.caption.copyWith(color: colors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The token's listed logo, or its first letter while it loads or when it has none.
class TokenLogo extends ConsumerWidget {
  final SwapToken token;
  final double size;

  const TokenLogo({super.key, required this.token, this.size = 32});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final icon = ref.watch(swapTokenIconProvider(token)).value;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: icon == null
            ? ColoredBox(
                color: colors.bgSurface2,
                child: Center(
                  child: Text(
                    token.symbol.isEmpty ? '?' : token.symbol[0],
                    style: text.labelMonogram.copyWith(color: colors.textContent),
                  ),
                ),
              )
            : icon.isSvg
            ? SvgPicture.memory(icon.bytes, fit: BoxFit.cover)
            : Image.memory(icon.bytes, fit: BoxFit.cover),
      ),
    );
  }
}
