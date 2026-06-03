import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

typedef SwapTokenLoader = Future<List<SwapToken>> Function({bool forceRefresh});

Future<SwapToken?> showTokenPickerSheet(
  BuildContext context, {
  required SwapTokenLoader loadTokens,
  required SwapToken current,
}) {
  return BottomSheetContainer.show<SwapToken>(
    context,
    builder: (_) => _TokenPickerContent(loadTokens: loadTokens, current: current),
  );
}

class _TokenPickerContent extends ConsumerStatefulWidget {
  final SwapTokenLoader loadTokens;
  final SwapToken current;
  const _TokenPickerContent({required this.loadTokens, required this.current});

  @override
  ConsumerState<_TokenPickerContent> createState() => _TokenPickerContentState();
}

class _TokenPickerContentState extends ConsumerState<_TokenPickerContent> {
  final _scrollController = ScrollController();
  List<SwapToken> _tokens = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTokens({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tokens = await widget.loadTokens(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Token picker load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ref.read(l10nProvider).swapTokenPickerLoadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final cardHeight = (height - 120).clamp(360.0, 506.0);

    return BottomSheetContainer(
      title: l10n.swapTokenPickerTitle,
      height: cardHeight,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: _content(l10n, colors, text),
      ),
    );
  }

  Widget _content(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    if (_loading && _tokens.isEmpty) {
      return const Center(child: Loader());
    }
    if (_error != null && _tokens.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: text.smallParagraph?.copyWith(color: colors.textSecondary, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _loadTokens(forceRefresh: true),
              child: Text(
                l10n.posQrTryAgain,
                style: text.paragraph?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (_error != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: text.detail?.copyWith(color: colors.textSecondary, decoration: TextDecoration.none),
                ),
              ),
              GestureDetector(
                onTap: () => _loadTokens(forceRefresh: true),
                child: Text(
                  l10n.posQrTryAgain,
                  style: text.detail?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: RefreshIndicator(
            color: colors.textPrimary,
            onRefresh: () => _loadTokens(forceRefresh: true),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              radius: const Radius.circular(25),
              thickness: 4,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _tokens.length,
                itemBuilder: (_, index) => _tokenRow(context, _tokens[index], colors, text),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tokenRow(BuildContext context, SwapToken token, AppColorsV2 colors, AppTextTheme text) {
    final selected = token == widget.current;
    return GestureDetector(
      onTap: () => Navigator.pop(context, token),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: Colors.white.withValues(alpha: 0.44), width: 0.9) : null,
        ),
        child: Row(
          children: [
            TokenIcon(token: token),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.symbol,
                    style: text.paragraph?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    token.network,
                    style: text.paragraph?.copyWith(color: colors.textSecondary, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
