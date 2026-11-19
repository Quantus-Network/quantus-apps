import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/ui/components/key_caps.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A keyboard shortcut that can be changed by pressing new keys.
///
/// At rest it shows [combo] as [KeyCaps], or [noneLabel] when there is none.
/// A click, or Space or Return while it has the focus, asks to record
/// ([onStart]); the owner then sets [isRecording]. While recording it shows
/// [recordingLabel] in a field ringed in the accent, takes every key, and
/// reports what was pressed: keys held with modifiers ([onKeys]), Escape
/// ([onCancel]), Delete or Backspace ([onRemove]). Keys the owner refused
/// stay in the field in the warning colour as [refused] until others are
/// pressed. Losing the focus while recording cancels.
///
/// At rest it behaves as the sheet's other controls: a backing under the
/// cursor, stronger while pressed, a ring for the focus.
class ShortcutRecorder extends StatefulWidget {
  const ShortcutRecorder({
    super.key,
    required this.combo,
    required this.isMac,
    required this.isRecording,
    required this.noneLabel,
    required this.recordingLabel,
    required this.semanticLabel,
    required this.onStart,
    required this.onKeys,
    required this.onCancel,
    required this.onRemove,
    this.refused,
  });

  final KeyCombo? combo;
  final bool isMac;
  final bool isRecording;
  final String noneLabel;
  final String recordingLabel;

  /// What a screen reader calls it: the command the shortcut is for.
  final String semanticLabel;

  final VoidCallback onStart;
  final ValueChanged<KeyCombo> onKeys;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  /// Keys pressed while recording that were not taken.
  final KeyCombo? refused;

  /// How far the keys sit inside the backing and ring. A row lets the two
  /// reach out by this much, so the keys end on its content edge.
  static const double inset = 8;

  @override
  State<ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends State<ShortcutRecorder> {
  final _focus = FocusNode(debugLabel: 'shortcut recorder');
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  static final _modifierKeys = {
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.fn,
  };

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ShortcutRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recording takes the keys, so it takes the focus.
    if (widget.isRecording && !oldWidget.isRecording) _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focus.hasFocus);
    if (!_focus.hasFocus && widget.isRecording) widget.onCancel();
  }

  void _start() {
    _focus.requestFocus();
    widget.onStart();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.isRecording) {
      final isPress = event is KeyDownEvent;
      if (isPress && (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.enter)) {
        _start();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    // Every key is the recorder's while it records: none may reach a
    // shortcut or close the sheet.
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onCancel();
    } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      widget.onRemove();
    } else if (!_modifierKeys.contains(key)) {
      final keyboard = HardwareKeyboard.instance;
      widget.onKeys(
        KeyCombo(
          key,
          KeyModifiers(
            meta: keyboard.isMetaPressed,
            control: keyboard.isControlPressed,
            alt: keyboard.isAltPressed,
            shift: keyboard.isShiftPressed,
          ),
        ),
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final refused = widget.refused;
    final combo = widget.combo;

    final Widget content;
    final Color? border;
    if (widget.isRecording && refused != null) {
      content = KeyCaps(combo: refused, isMac: widget.isMac, color: colors.semanticEmber);
      border = colors.semanticEmber;
    } else if (widget.isRecording) {
      content = Text(widget.recordingLabel, style: text.body.copyWith(color: colors.textMuted, height: 1));
      border = colors.accentFlare;
    } else {
      content = combo == null
          ? Text(widget.noneLabel, style: text.body.copyWith(color: colors.textMuted, height: 1))
          : KeyCaps(combo: combo, isMac: widget.isMac);
      border = _isFocused ? colors.accentFlare.useOpacity(0.7) : null;
    }

    final radius = BorderRadius.circular(context.radiusV3.sm);
    final backing = widget.isRecording
        ? colors.bgSurface
        : colors.textContent.useOpacity(_isPressed ? 0.10 : (_isHovered ? 0.05 : 0));

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      value: widget.isRecording ? widget.recordingLabel : null,
      onTap: widget.isRecording ? null : _start,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.isRecording ? null : _start,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: border == null ? null : Border.all(color: border, width: 1.5),
              ),
              child: Container(
                constraints: const BoxConstraints(minWidth: 112, minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: ShortcutRecorder.inset, vertical: 4),
                alignment: widget.isRecording ? Alignment.center : Alignment.centerRight,
                decoration: BoxDecoration(color: backing, borderRadius: radius),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
