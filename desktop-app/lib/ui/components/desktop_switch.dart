import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A mini switch for one row of a list, as the macOS guidelines give a row
/// of a grouped form. Tab reaches it and Space toggles it. With no
/// [onChanged] it is dimmed and does none of this.
class DesktopSwitch extends StatefulWidget {
  const DesktopSwitch({super.key, required this.value, required this.label, required this.onChanged});

  final bool value;

  /// What a screen reader names it; the row around it shows the same.
  final String label;

  /// What a toggle reports. Null makes the switch unavailable.
  final ValueChanged<bool>? onChanged;

  static const double _trackWidth = 28;
  static const double _trackHeight = 16;
  static const double _thumb = 12;

  /// The clear space between the track and the focus ring.
  static const double _ringGap = 2;

  static const _slide = Duration(milliseconds: 120);

  @override
  State<DesktopSwitch> createState() => _DesktopSwitchState();
}

class _DesktopSwitchState extends State<DesktopSwitch> {
  bool _isHovered = false;
  bool _isFocused = false;

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final isEnabled = widget.onChanged != null;
    final isOn = widget.value;
    final slide = MediaQuery.disableAnimationsOf(context) ? Duration.zero : DesktopSwitch._slide;
    final trackColor = switch ((isOn, _isHovered && isEnabled)) {
      (true, false) => colors.accentFlare,
      (true, true) => colors.accentFlare.useOpacity(0.85),
      (false, false) => colors.bgVoid,
      (false, true) => colors.textContent.useOpacity(0.08),
    };

    return Semantics(
      container: true,
      toggled: isOn,
      enabled: isEnabled,
      label: widget.label,
      onTap: isEnabled ? _toggle : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.4,
        child: FocusableActionDetector(
          enabled: isEnabled,
          mouseCursor: SystemMouseCursors.basic,
          onShowHoverHighlight: (isHovered) => setState(() => _isHovered = isHovered),
          onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle())},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isEnabled ? _toggle : null,
            child: Container(
              padding: const EdgeInsets.all(DesktopSwitch._ringGap),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DesktopSwitch._trackHeight / 2 + DesktopSwitch._ringGap),
                border: _isFocused
                    ? Border.all(
                        color: colors.accentFlare.useOpacity(0.7),
                        width: DesktopSwitch._ringGap,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      )
                    : null,
              ),
              child: AnimatedContainer(
                duration: slide,
                width: DesktopSwitch._trackWidth,
                height: DesktopSwitch._trackHeight,
                padding: const EdgeInsets.all((DesktopSwitch._trackHeight - DesktopSwitch._thumb) / 2),
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(DesktopSwitch._trackHeight / 2),
                  border: Border.all(color: isOn ? colors.accentFlare : colors.borderEmphasis),
                ),
                child: Container(
                  width: DesktopSwitch._thumb,
                  height: DesktopSwitch._thumb,
                  decoration: BoxDecoration(color: isOn ? colors.textVoid : colors.textMuted, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
