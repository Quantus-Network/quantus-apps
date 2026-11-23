import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/swap_token_mark.dart';
import 'package:quantus_desktop_wallet/ui/send/send_form_parts.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One side of a swap on its form: what the side is, whose it is, its
/// [amount] over that in dollars, and its [token] at the end. The side being
/// typed on [isActive], and is edged in the accent.
class SwapSideBox extends StatelessWidget {
  const SwapSideBox({
    super.key,
    required this.label,
    required this.owner,
    required this.amount,
    required this.usd,
    required this.token,
    required this.isActive,
  });

  final String label;
  final String owner;
  final Widget amount;
  final String usd;
  final Widget token;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: colors.bgVoid,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: isActive ? colors.accentFlare : colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CapsText(label, style: context.sendCaps()),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  owner,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.sendBody(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: SwapTokenButton.height,
            child: Row(
              children: [
                Expanded(child: amount),
                const SizedBox(width: 12),
                token,
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(usd, style: context.themeTextV3.caption.copyWith(color: colors.textMuted2)),
        ],
      ),
    );
  }
}

/// A token as a side names it: its mark, its symbol, and the chain it is on.
class SwapTokenLabel extends StatelessWidget {
  const SwapTokenLabel({super.key, required this.token});

  final SwapToken token;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwapTokenMark(token: token),
        const SizedBox(width: 8),
        Text(token.symbol, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            token.networkName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.body.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// The token of the side on another chain, as a button that opens the list
/// of tokens to pick another from.
class SwapTokenButton extends StatefulWidget {
  const SwapTokenButton({super.key, required this.token, required this.semanticLabel, required this.onPressed});

  final SwapToken token;
  final String semanticLabel;
  final VoidCallback onPressed;

  static const double height = 32;

  @override
  State<SwapTokenButton> createState() => _SwapTokenButtonState();
}

class _SwapTokenButtonState extends State<SwapTokenButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      value: '${widget.token.symbol} ${widget.token.networkName}',
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (isHovered) => setState(() => _isHovered = isHovered),
        onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            height: SwapTokenButton.height,
            padding: const EdgeInsets.only(left: 8, right: 8),
            decoration: BoxDecoration(
              color: colors.textContent.useOpacity(_isHovered ? 0.08 : 0.04),
              borderRadius: context.radiusV3.smBorder,
              border: Border.all(
                color: _isFocused ? colors.accentFlare.useOpacity(0.7) : colors.borderEmphasis,
                width: _isFocused ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: SwapTokenLabel(token: widget.token)),
                const SizedBox(width: 8),
                Icon(CupertinoIcons.chevron_up_chevron_down, size: 11, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the list of [tokens] under the widget [anchor] belongs to, with a
/// field that narrows it to a symbol or a chain. Answers the token picked;
/// null when it was closed without one.
Future<SwapToken?> showSwapTokenList(
  BuildContext anchor, {
  required List<SwapToken> tokens,
  required SwapToken current,
  required String searchHint,
  required String noMatch,
  required Key searchKey,
  required Key listKey,
  required Key Function(SwapToken token) rowKey,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final navigator = Navigator.of(anchor);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final button = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;

  return navigator.push(
    _TokenListRoute(
      button: button,
      barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
      child: _TokenList(
        tokens: tokens,
        current: current,
        searchHint: searchHint,
        noMatch: noMatch,
        searchKey: searchKey,
        listKey: listKey,
        rowKey: rowKey,
      ),
    ),
  );
}

class _TokenListRoute extends PopupRoute<SwapToken> {
  _TokenListRoute({required this.button, required this.barrierLabel, required this.child});

  final Rect button;
  final Widget child;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return CustomSingleChildLayout(delegate: _TokenListLayout(button), child: child);
  }
}

/// Puts the list under its button, its right edge on the button's, and keeps
/// it within the window: it opens over the button where there is no room
/// under it.
class _TokenListLayout extends SingleChildLayoutDelegate {
  const _TokenListLayout(this.button);

  final Rect button;

  static const double _margin = 6;
  static const double _gap = 4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(constraints.maxWidth - 2 * _margin, constraints.maxHeight - 2 * _margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (button.right - childSize.width).clamp(_margin, size.width - childSize.width - _margin);
    final under = button.bottom + _gap;
    final top = under + childSize.height + _margin <= size.height ? under : size.height - childSize.height - _margin;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TokenListLayout oldDelegate) => button != oldDelegate.button;
}

class _TokenList extends StatefulWidget {
  const _TokenList({
    required this.tokens,
    required this.current,
    required this.searchHint,
    required this.noMatch,
    required this.searchKey,
    required this.listKey,
    required this.rowKey,
  });

  final List<SwapToken> tokens;
  final SwapToken current;
  final String searchHint;
  final String noMatch;
  final Key searchKey;
  final Key listKey;
  final Key Function(SwapToken token) rowKey;

  @override
  State<_TokenList> createState() => _TokenListState();
}

class _TokenListState extends State<_TokenList> {
  static const double _width = 320;
  static const double _listHeight = 264;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// The tokens whose symbol, chain or chain's code holds what is typed.
  List<SwapToken> get _matches {
    final typed = _search.text.trim().toLowerCase();
    if (typed.isEmpty) return widget.tokens;
    return [
      for (final token in widget.tokens)
        if (token.symbol.toLowerCase().contains(typed) ||
            token.networkName.toLowerCase().contains(typed) ||
            token.network.toLowerCase().contains(typed))
          token,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.smBorder;
    final matches = _matches;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: _width,
        decoration: BoxDecoration(
          color: colors.bgSurface2,
          borderRadius: radius,
          border: Border.all(color: colors.borderEmphasis),
          boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SendField(
              key: widget.searchKey,
              controller: _search,
              focusNode: _searchFocus,
              hint: widget.searchHint,
              style: context.themeTextV3.body.copyWith(color: colors.textContent),
              // Return picks the first of what is left.
              onSubmitted: (_) {
                if (matches.isNotEmpty) Navigator.of(context).pop(matches.first);
              },
            ),
            const SizedBox(height: 6),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Text(widget.noMatch, style: context.sendBody()),
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: _listHeight),
                  child: ListView.builder(
                    key: widget.listKey,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemExtent: _TokenRow.height,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final token = matches[index];
                      return _TokenRow(
                        key: widget.rowKey(token),
                        token: token,
                        isCurrent: token == widget.current,
                        onPressed: () => Navigator.of(context).pop(token),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One token of the list; the one the side has is ticked.
class _TokenRow extends StatefulWidget {
  const _TokenRow({super.key, required this.token, required this.isCurrent, required this.onPressed});

  final SwapToken token;
  final bool isCurrent;
  final VoidCallback onPressed;

  static const double height = 34;

  @override
  State<_TokenRow> createState() => _TokenRowState();
}

class _TokenRowState extends State<_TokenRow> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Semantics(
      button: true,
      selected: widget.isCurrent,
      label: '${widget.token.symbol} ${widget.token.networkName}',
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (isHovered) => setState(() => _isHovered = isHovered),
        onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colors.textContent.useOpacity(_isHovered || _isFocused ? 0.08 : 0),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SwapTokenLabel(token: widget.token),
                  ),
                ),
                if (widget.isCurrent) Icon(CupertinoIcons.checkmark, size: 12, color: colors.accentFlare),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
