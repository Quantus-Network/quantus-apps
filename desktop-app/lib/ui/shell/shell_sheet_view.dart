import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/receive/receive_sheet.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// A sheet over the window, hanging from under the header as a macOS sheet
/// hangs from the title bar: a title row with a way out, then the sheet's
/// own content. A sheet that acts on the active account names it in the
/// title row. Each feature fills in its own sheet as it arrives; one with
/// steps of its own (Send, Settings) draws its own title row.
class ShellSheetView extends ConsumerWidget {
  const ShellSheetView({super.key, required this.sheet});

  final ShellSheet sheet;

  /// How wide a sheet grows, when the pane leaves room.
  static const double maxWidth = 700;

  /// The margin between the sheet's border and its content.
  static const double padding = 24;

  bool get _actsOnAccount => switch (sheet) {
    ShellSheet.receive || ShellSheet.send || ShellSheet.propose || ShellSheet.swap => true,
    ShellSheet.addAccount || ShellSheet.settings => false,
  };

  Widget? get _content => switch (sheet) {
    ShellSheet.receive => const ReceiveSheet(),
    ShellSheet.send || ShellSheet.propose || ShellSheet.swap || ShellSheet.addAccount || ShellSheet.settings => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final radius = Radius.circular(context.radiusV3.lg);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: radius),
        boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.6), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: Material(
        color: colors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: radius),
          side: BorderSide(color: colors.borderHairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: switch (sheet) {
            ShellSheet.settings => const SettingsSheet(),
            ShellSheet.send => const SendSheet(),
            _ => _titledContent(ref),
          },
        ),
      ),
    );
  }

  Widget _titledContent(WidgetRef ref) {
    final account = _actsOnAccount ? ref.watch(activeAccountProvider).value?.account : null;
    final content = _content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellSheetHeader(title: sheetTitle(ref.watch(l10nProvider), sheet), account: account),
        if (content != null) ...[const SizedBox(height: 18), content],
      ],
    );
  }
}

/// A sheet's title row, on the content's edges: the title, from the
/// content's left edge, and the close cross, ending on its right edge. A
/// sheet that acts on an account names it after the title.
///
/// A step opened from another level of the sheet shows the way it came as a
/// small, dim path, "Settings › Recovery Phrase", in place of a title; the
/// [parent] level's name is the way back.
class ShellSheetHeader extends ConsumerWidget {
  const ShellSheetHeader({super.key, required this.title, this.account, this.parent});

  final String title;
  final BaseAccount? account;

  /// The level this step was opened from: its title, and going back to it.
  final ({String title, VoidCallback onBack})? parent;

  static const backKey = Key('shell-sheet-back');
  static const closeGlyphKey = Key('shell-sheet-close-glyph');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = this.account;
    final parent = this.parent;
    // A top-level title stands out; on a step the whole path is quiet, the
    // step's name the same as its parent's, and the step's content leads.
    final titleStyle = parent == null
        ? text.titleScreen.copyWith(color: colors.textContent)
        : text.body.copyWith(color: colors.textMuted2);

    return Row(
      children: [
        // The path, the title and the account take the row; the close cross
        // keeps to the end.
        Expanded(
          child: Row(
            children: [
              // The path's parts share a baseline.
              Flexible(
                child: Row(
                  // As wide as the path and title, so what follows stays
                  // beside them.
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (parent != null) ...[
                      _ParentLink(
                        key: backKey,
                        title: parent.title,
                        hint: MaterialLocalizations.of(context).backButtonTooltip,
                        style: text.body,
                        onBack: parent.onBack,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(CupertinoIcons.chevron_forward, size: 11, color: colors.textMuted2),
                      ),
                    ],
                    Flexible(
                      child: Text(title, overflow: TextOverflow.ellipsis, style: titleStyle),
                    ),
                  ],
                ),
              ),
              if (account != null) ...[
                const SizedBox(width: 14),
                DesktopAccountBadge(account: account, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    account.name,
                    overflow: TextOverflow.ellipsis,
                    style: text.body.copyWith(color: colors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Asked, not told: a sheet in the middle of something that cannot be
        // interrupted stays open.
        _CloseButton(tooltip: l10n.commonClose, onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}

/// The parent level's title in a path, small and dim, brightening under the
/// cursor;
/// pressing it goes back. A screen reader hears it as a Back button named
/// for where it goes.
class _ParentLink extends StatefulWidget {
  const _ParentLink({super.key, required this.title, required this.hint, required this.style, required this.onBack});

  final String title;
  final String hint;
  final TextStyle style;
  final VoidCallback onBack;

  @override
  State<_ParentLink> createState() => _ParentLinkState();
}

class _ParentLinkState extends State<_ParentLink> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Semantics(
      button: true,
      label: widget.title,
      hint: widget.hint,
      onTap: widget.onBack,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (isHovered) => setState(() => _isHovered = isHovered),
        onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onBack())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBack,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: _isFocused ? Border.all(color: colors.accentFlare.useOpacity(0.7), width: 2) : null,
            ),
            child: Text(
              widget.title,
              style: widget.style.copyWith(color: _isHovered ? colors.textMuted : colors.textMuted2),
            ),
          ),
        ),
      ),
    );
  }
}

/// The close cross. Its glyph ends on the content's right edge; its hover
/// backing reaches past the edge into the sheet's margin, where clicks miss,
/// since the content's bounds end at the edge.
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  static const double _size = 28;
  static const double _glyph = 15;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    // How far the glyph sits in from its click area's edge.
    const inset = (_CloseButton._size - _CloseButton._glyph) / 2;

    return Transform.translate(
      offset: const Offset(inset, 0),
      child: Tooltip(
        message: widget.tooltip,
        child: Semantics(
          button: true,
          label: widget.tooltip,
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
                width: _CloseButton._size,
                height: _CloseButton._size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.textContent.useOpacity(_isHovered ? 0.06 : 0),
                  borderRadius: BorderRadius.circular(6),
                  border: _isFocused ? Border.all(color: colors.accentFlare.useOpacity(0.7), width: 2) : null,
                ),
                child: Icon(
                  CupertinoIcons.xmark,
                  key: ShellSheetHeader.closeGlyphKey,
                  size: _CloseButton._glyph,
                  color: colors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Takes a step-by-step sheet back a level from the keyboard: Command-[ on
/// macOS, as Finder and System Settings do, and Alt-Left on Windows and
/// Linux. With no [onBack], at the top level, the keys do nothing.
class SheetBackShortcut extends StatelessWidget {
  const SheetBackShortcut({super.key, required this.onBack, required this.child});

  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final activator = defaultTargetPlatform == TargetPlatform.macOS
        ? const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true)
        : const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true);

    return CallbackShortcuts(
      bindings: {activator: ?onBack},
      // Holds the focus when nothing in the sheet has it, so the keys reach
      // the bindings above.
      child: Focus(autofocus: true, skipTraversal: true, child: child),
    );
  }
}
