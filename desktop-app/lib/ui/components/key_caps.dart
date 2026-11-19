import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A keyboard shortcut drawn as the keys to press: one small key for each.
///
/// On the Mac ([isMac]) a modifier key shows its symbol and its name, as
/// the keyboard prints them ("⌘ command"), in the order macOS writes them.
/// Elsewhere a modifier key is named only ("Ctrl"), as those keyboards have
/// no symbols. The symbols are drawn as icons: the app's fonts have none.
class KeyCaps extends StatelessWidget {
  const KeyCaps({super.key, required this.combo, required this.isMac, this.color});

  final KeyCombo combo;
  final bool isMac;

  /// The colour of the keys' writing, when not the content colour.
  final Color? color;

  static const double _height = 24;

  /// The modifiers held, in the order the platform writes them.
  List<({String name, IconData? icon})> get _modifiers {
    final held = combo.modifiers;
    return isMac
        ? [
            if (held.control) (name: 'control', icon: CupertinoIcons.control),
            if (held.alt) (name: 'option', icon: CupertinoIcons.option),
            if (held.shift) (name: 'shift', icon: CupertinoIcons.shift),
            if (held.meta) (name: 'command', icon: CupertinoIcons.command),
          ]
        : [
            if (held.meta) (name: 'Win', icon: null),
            if (held.control) (name: 'Ctrl', icon: null),
            if (held.alt) (name: 'Alt', icon: null),
            if (held.shift) (name: 'Shift', icon: null),
          ];
  }

  /// What each key says, in order: the modifiers' names, then the key's.
  List<String> get labels => [for (final modifier in _modifiers) modifier.name, keyName(combo.key)];

  /// What [key] is called on its key: arrows by their arrow, a letter by
  /// its capital.
  static String keyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    final label = key.keyLabel;
    if (label.isEmpty) return key.debugName ?? 'Key ${key.keyId}';
    return label.length == 1 ? label.toUpperCase() : label;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final ink = color ?? colors.textContent;

    Widget key(Widget child) => Container(
      constraints: const BoxConstraints(minWidth: _height),
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(context.radiusV3.xs),
        border: Border.all(color: colors.borderHairline),
        // The key's lower edge, as a keycap's.
        boxShadow: [BoxShadow(color: colors.borderEmphasis, offset: const Offset(0, 1.5))],
      ),
      child: child,
    );

    final keys = [
      for (final modifier in _modifiers)
        key(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (modifier.icon case final icon?) ...[Icon(icon, size: 12, color: ink), const SizedBox(width: 4)],
              Text(modifier.name, style: (isMac ? text.caption : text.body).copyWith(color: ink, height: 1)),
            ],
          ),
        ),
      key(Text(keyName(combo.key), style: text.body.copyWith(color: ink, height: 1))),
    ];

    return Semantics(
      label: labels.join(' '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, cap) in keys.indexed) ...[if (index > 0) const SizedBox(width: 4), cap],
        ],
      ),
    );
  }
}
