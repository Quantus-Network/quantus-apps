import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/search_field.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

typedef SwapTokenLoader = Future<List<SwapToken>> Function({bool forceRefresh});

Future<SwapToken?> showTokenPickerSheet(
  BuildContext context, {
  required SwapTokenLoader loadTokens,
  required SwapToken current,
}) {
  return BottomSheetContainer.show<SwapToken>(
    context,
    fullScreen: true,
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
  final _searchController = TextEditingController();
  List<SwapToken> _tokens = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTokens();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

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
      quantusPrint('Token picker load failed: $e');
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return BottomSheetContainer(
      title: l10n.swapTokenPickerTitle,
      height: double.infinity,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: _content(l10n, colors, text),
      ),
    );
  }

  Widget _content(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    if (_loading && _tokens.isEmpty) {
      return const Center(child: Loader());
    }
    if (_error != null && _tokens.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: text.body.copyWith(color: colors.textMuted)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _loadTokens(forceRefresh: true),
              child: Text(l10n.commonTryAgain, style: text.body.copyWith(color: colors.accentFlare)),
            ),
          ],
        ),
      );
    }
    final query = _searchController.text.trim().toUpperCase();
    final tokens = _tokens
        .where(
          (t) => t.symbol.contains(query) || t.network.contains(query) || t.networkName.toUpperCase().contains(query),
        )
        .toList();
    return Column(
      children: [
        SearchField(controller: _searchController, hintText: l10n.swapTokenPickerSearchHint),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(_error!, style: text.caption.copyWith(color: colors.textMuted)),
              ),
              GestureDetector(
                onTap: () => _loadTokens(forceRefresh: true),
                child: Text(l10n.commonTryAgain, style: text.caption.copyWith(color: colors.accentFlare)),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (tokens.isEmpty)
          Text(l10n.swapTokenPickerNoMatch, style: text.caption.copyWith(color: colors.textMuted))
        else
          Expanded(
            child: RefreshIndicator(
              color: colors.accentFlare,
              onRefresh: () => _loadTokens(forceRefresh: true),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                radius: Radius.circular(context.radiusV3.md),
                thickness: 4,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: tokens.length,
                  itemBuilder: (_, index) => _tokenRow(context, tokens[index], colors, text),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tokenRow(BuildContext context, SwapToken token, AppColorsV3 colors, AppTextThemeV3 text) {
    final selected = token == widget.current;
    return GestureDetector(
      onTap: () => Navigator.pop(context, token),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: context.radiusV3.mdBorder,
          border: selected ? Border.all(color: colors.borderEmphasis) : null,
        ),
        child: Row(
          children: [
            TokenIcon(token: token),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(token.symbol, style: text.headingRow.copyWith(color: colors.textContent)),
                  const SizedBox(height: 4),
                  Text(token.networkName, style: text.body.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
