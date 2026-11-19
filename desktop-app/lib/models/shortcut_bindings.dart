import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';

/// The modifier keys held with a key. [meta] is ⌘ on the Mac and the
/// Windows (Super) key elsewhere; [alt] is ⌥ on the Mac.
@immutable
class KeyModifiers {
  const KeyModifiers({this.meta = false, this.control = false, this.alt = false, this.shift = false});

  final bool meta;
  final bool control;
  final bool alt;
  final bool shift;

  Map<String, bool> toJson() => {'meta': meta, 'control': control, 'alt': alt, 'shift': shift};

  static KeyModifiers fromJson(Object? json) {
    if (json is! Map) throw FormatException('Modifiers are not a map: $json');
    bool flag(String name) => switch (json[name]) {
      final bool value => value,
      final other => throw FormatException('Modifier "$name" is not true or false: $other'),
    };
    return KeyModifiers(meta: flag('meta'), control: flag('control'), alt: flag('alt'), shift: flag('shift'));
  }

  @override
  bool operator ==(Object other) =>
      other is KeyModifiers &&
      other.meta == meta &&
      other.control == control &&
      other.alt == alt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(meta, control, alt, shift);

  @override
  String toString() =>
      'KeyModifiers(${[if (meta) 'meta', if (control) 'control', if (alt) 'alt', if (shift) 'shift'].join('+')})';
}

/// A key pressed with [modifiers]: one keyboard shortcut.
@immutable
class KeyCombo {
  const KeyCombo(this.key, this.modifiers);

  final LogicalKeyboardKey key;
  final KeyModifiers modifiers;

  SingleActivator get activator => SingleActivator(
    key,
    meta: modifiers.meta,
    control: modifiers.control,
    alt: modifiers.alt,
    shift: modifiers.shift,
  );

  Map<String, Object> toJson() => {'key': key.keyId, ...modifiers.toJson()};

  static KeyCombo fromJson(Object? json) {
    if (json is! Map) throw FormatException('A shortcut is not a map: $json');
    final keyId = json['key'];
    if (keyId is! int) throw FormatException('A shortcut\'s key is not a number: $keyId');
    // An id is a plane and a value in it, forty bits in all.
    if (keyId < 0 || keyId > (LogicalKeyboardKey.planeMask | LogicalKeyboardKey.valueMask)) {
      throw FormatException('No key has the id $keyId.');
    }
    // As the framework reads a key event: a key it has no constant for, a
    // keyboard's own letter say, is a key of that id all the same.
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);
    return KeyCombo(key, KeyModifiers.fromJson(json));
  }

  @override
  bool operator ==(Object other) => other is KeyCombo && other.key == key && other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(key, modifiers);

  @override
  String toString() => 'KeyCombo(${key.debugName} $modifiers)';
}

/// Why a shortcut cannot be given to a command.
sealed class ShortcutRefusal {
  const ShortcutRefusal();
}

/// Another command has it.
class UsedByCommand extends ShortcutRefusal {
  const UsedByCommand(this.command);

  final AppCommand command;

  @override
  bool operator ==(Object other) => other is UsedByCommand && other.command == command;

  @override
  int get hashCode => command.hashCode;
}

/// It is the account keys with a digit, which go to an account.
class UsedByAccounts extends ShortcutRefusal {
  const UsedByAccounts();

  @override
  bool operator ==(Object other) => other is UsedByAccounts;

  @override
  int get hashCode => 0;
}

/// The system keeps it for [command].
class KeptForSystem extends ShortcutRefusal {
  const KeptForSystem(this.command);

  final SystemCommand command;

  @override
  bool operator ==(Object other) => other is KeptForSystem && other.command == command;

  @override
  int get hashCode => command.hashCode;
}

/// No modifier that makes a shortcut is held, so the key would be lost to
/// typing.
class NeedsModifier extends ShortcutRefusal {
  const NeedsModifier();

  @override
  bool operator ==(Object other) => other is NeedsModifier;

  @override
  int get hashCode => 1;
}

/// The Windows (Super) key is held, whose shortcuts are the system's.
class UsesSystemKey extends ShortcutRefusal {
  const UsesSystemKey();

  @override
  bool operator ==(Object other) => other is UsesSystemKey;

  @override
  int get hashCode => 2;
}

/// The key cannot be a menu item's in the Mac's menu bar, which is where
/// the Mac's shortcuts live.
class KeyNotForMenuBar extends ShortcutRefusal {
  const KeyNotForMenuBar();

  @override
  bool operator ==(Object other) => other is KeyNotForMenuBar;

  @override
  int get hashCode => 3;
}

/// The keyboard shortcuts of the app's commands on one platform: the
/// defaults, with what the person changed over them.
///
/// Shortcuts use ⌘ on the Mac ([isMac]) and Ctrl elsewhere. A change that
/// another command, the account keys or the system already has is refused
/// ([refusal]), so no two commands ever share keys.
@immutable
class ShortcutBindings {
  const ShortcutBindings.defaults({required this.isMac}) : _changed = const {}, _accountModifiers = null;

  const ShortcutBindings._(this.isMac, this._changed, this._accountModifiers);

  final bool isMac;

  /// The commands whose shortcut was changed; null for one removed.
  final Map<AppCommand, KeyCombo?> _changed;

  /// The account keys, when changed.
  final KeyModifiers? _accountModifiers;

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// The command key: ⌘ on the Mac, Ctrl elsewhere.
  KeyModifiers get _command => isMac ? const KeyModifiers(meta: true) : const KeyModifiers(control: true);

  /// The command key with ⌥ on the Mac, Ctrl+Alt elsewhere.
  KeyModifiers get _commandAlt =>
      isMac ? const KeyModifiers(meta: true, alt: true) : const KeyModifiers(control: true, alt: true);

  KeyCombo _defaultOf(AppCommand command) => switch (command) {
    AppCommand.receive => KeyCombo(LogicalKeyboardKey.keyR, _command),
    AppCommand.send => KeyCombo(LogicalKeyboardKey.keyS, _command),
    AppCommand.propose => KeyCombo(LogicalKeyboardKey.keyP, _command),
    AppCommand.addAccount => KeyCombo(LogicalKeyboardKey.keyN, _command),
    AppCommand.toggleSidebar => KeyCombo(LogicalKeyboardKey.keyB, _command),
    AppCommand.nextSidebarItem => KeyCombo(LogicalKeyboardKey.arrowDown, _commandAlt),
    AppCommand.previousSidebarItem => KeyCombo(LogicalKeyboardKey.arrowUp, _commandAlt),
  };

  /// The keys the system keeps, and what for.
  Map<KeyCombo, SystemCommand> get _reserved => isMac
      ? {
          KeyCombo(LogicalKeyboardKey.comma, _command): SystemCommand.settings,
          KeyCombo(LogicalKeyboardKey.keyW, _command): SystemCommand.closeWindow,
          KeyCombo(LogicalKeyboardKey.keyQ, _command): SystemCommand.quit,
          KeyCombo(LogicalKeyboardKey.keyH, _command): SystemCommand.hide,
          KeyCombo(LogicalKeyboardKey.keyH, _commandAlt): SystemCommand.hideOthers,
          KeyCombo(LogicalKeyboardKey.keyM, _command): SystemCommand.minimize,
          const KeyCombo(LogicalKeyboardKey.keyF, KeyModifiers(meta: true, control: true)): SystemCommand.fullScreen,
          KeyCombo(LogicalKeyboardKey.keyX, _command): SystemCommand.cut,
          KeyCombo(LogicalKeyboardKey.keyC, _command): SystemCommand.copy,
          KeyCombo(LogicalKeyboardKey.keyV, _command): SystemCommand.paste,
          KeyCombo(LogicalKeyboardKey.keyA, _command): SystemCommand.selectAll,
          KeyCombo(LogicalKeyboardKey.keyZ, _command): SystemCommand.undo,
          const KeyCombo(LogicalKeyboardKey.keyZ, KeyModifiers(meta: true, shift: true)): SystemCommand.redo,
        }
      : {
          KeyCombo(LogicalKeyboardKey.comma, _command): SystemCommand.settings,
          KeyCombo(LogicalKeyboardKey.keyW, _command): SystemCommand.closeWindow,
          const KeyCombo(LogicalKeyboardKey.f4, KeyModifiers(alt: true)): SystemCommand.quit,
          KeyCombo(LogicalKeyboardKey.keyX, _command): SystemCommand.cut,
          KeyCombo(LogicalKeyboardKey.keyC, _command): SystemCommand.copy,
          KeyCombo(LogicalKeyboardKey.keyV, _command): SystemCommand.paste,
          KeyCombo(LogicalKeyboardKey.keyA, _command): SystemCommand.selectAll,
          KeyCombo(LogicalKeyboardKey.keyZ, _command): SystemCommand.undo,
          KeyCombo(LogicalKeyboardKey.keyY, _command): SystemCommand.redo,
          // What Flutter's text fields also give Redo and Copy there.
          const KeyCombo(LogicalKeyboardKey.keyZ, KeyModifiers(control: true, shift: true)): SystemCommand.redo,
          KeyCombo(LogicalKeyboardKey.insert, _command): SystemCommand.copy,
        };

  /// The keys that print nothing which a menu item of the Mac's menu bar can
  /// have: the ones the Flutter engine knows a key equivalent for
  /// (`GetMacOsSpecialKeys` in its FlutterMenuPlugin.mm).
  static final _macMenuBarKeys = {
    LogicalKeyboardKey.backspace,
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
    LogicalKeyboardKey.f9,
    LogicalKeyboardKey.f10,
    LogicalKeyboardKey.f11,
    LogicalKeyboardKey.f12,
    LogicalKeyboardKey.f13,
    LogicalKeyboardKey.f14,
    LogicalKeyboardKey.f15,
    LogicalKeyboardKey.f16,
    LogicalKeyboardKey.f17,
    LogicalKeyboardKey.f18,
    LogicalKeyboardKey.f19,
    LogicalKeyboardKey.f20,
  };

  /// Whether a menu item can have [key] as its shortcut's key. On the Mac
  /// the shortcuts are the menu bar's, and the engine gives a menu item a
  /// key only for a character of one UTF-16 unit or one of
  /// [_macMenuBarKeys]; with any other key, a number pad's for one, the item
  /// is left with no shortcut. Elsewhere the app listens for the keys itself.
  bool _menuTakes(LogicalKeyboardKey key) {
    if (!isMac) return true;
    final isCharacter = (key.keyId & LogicalKeyboardKey.planeMask) == LogicalKeyboardKey.unicodePlane;
    if (isCharacter) return (key.keyId & LogicalKeyboardKey.valueMask) <= 0xffff;
    return _macMenuBarKeys.contains(key);
  }

  /// Settings, whose keys are fixed.
  KeyCombo get settings => KeyCombo(LogicalKeyboardKey.comma, _command);

  /// Close Window, whose keys are fixed.
  KeyCombo get closeWindow => KeyCombo(LogicalKeyboardKey.keyW, _command);

  /// [command]'s shortcut, or null when it has none.
  KeyCombo? operator [](AppCommand command) => _changed.containsKey(command) ? _changed[command] : _defaultOf(command);

  /// Whether [command]'s shortcut is the one the app ships with.
  bool isDefault(AppCommand command) => !_changed.containsKey(command);

  /// The keys held with a digit to go to an account.
  KeyModifiers get accountModifiers => _accountModifiers ?? _command;

  /// What the account keys can be.
  List<KeyModifiers> get accountModifierChoices => isMac
      ? const [KeyModifiers(meta: true), KeyModifiers(control: true), KeyModifiers(meta: true, alt: true)]
      : const [KeyModifiers(control: true), KeyModifiers(alt: true), KeyModifiers(control: true, alt: true)];

  /// The shortcut of the account at [index] in the sidebar's order, or null
  /// past the ninth: there are nine digits to give.
  KeyCombo? account(int index) => index < _digits.length ? KeyCombo(_digits[index], accountModifiers) : null;

  /// Why [combo] cannot be [command]'s shortcut, or null when it can.
  ShortcutRefusal? refusal(AppCommand command, KeyCombo combo) {
    final modifiers = combo.modifiers;
    if (!isMac && modifiers.meta) return const UsesSystemKey();
    if (!_menuTakes(combo.key)) return const KeyNotForMenuBar();
    final makesShortcut = modifiers.control || modifiers.alt || (isMac && modifiers.meta);
    if (!makesShortcut) return const NeedsModifier();
    final system = _reserved[combo];
    if (system != null) return KeptForSystem(system);
    if (modifiers == accountModifiers && _digits.contains(combo.key)) return const UsedByAccounts();
    for (final other in AppCommand.values) {
      if (other != command && this[other] == combo) return UsedByCommand(other);
    }
    return null;
  }

  /// Why [modifiers] cannot be the account keys, or null when they can.
  ShortcutRefusal? accountModifiersRefusal(KeyModifiers modifiers) {
    for (final command in AppCommand.values) {
      final combo = this[command];
      if (combo != null && combo.modifiers == modifiers && _digits.contains(combo.key)) return UsedByCommand(command);
    }
    return null;
  }

  /// These shortcuts with [command]'s set to [combo], or removed when it is
  /// null. Throws an [ArgumentError] when [combo] is refused ([refusal]).
  ShortcutBindings withShortcut(AppCommand command, KeyCombo? combo) {
    if (combo != null) {
      final refused = refusal(command, combo);
      if (refused != null) throw ArgumentError.value(combo, 'combo', 'refused for $command: $refused');
    }
    final changed = {..._changed, command: combo};
    if (combo == _defaultOf(command)) changed.remove(command);
    return ShortcutBindings._(isMac, Map.unmodifiable(changed), _accountModifiers);
  }

  /// These shortcuts with [modifiers] as the account keys. Throws an
  /// [ArgumentError] when they are refused ([accountModifiersRefusal]) or
  /// are not one of [accountModifierChoices].
  ShortcutBindings withAccountModifiers(KeyModifiers modifiers) {
    if (!accountModifierChoices.contains(modifiers)) {
      throw ArgumentError.value(modifiers, 'modifiers', 'not one of the account keys offered');
    }
    final refused = accountModifiersRefusal(modifiers);
    if (refused != null) throw ArgumentError.value(modifiers, 'modifiers', 'refused: $refused');
    return ShortcutBindings._(isMac, _changed, modifiers == _command ? null : modifiers);
  }

  /// What was changed from the defaults, to be stored.
  Map<String, Object?> toJson() => {
    'commands': {for (final MapEntry(:key, :value) in _changed.entries) key.name: value?.toJson()},
    if (_accountModifiers case final modifiers?) 'accountModifiers': modifiers.toJson(),
  };

  /// Reads what [toJson] stored. Throws a [FormatException] for anything it
  /// would not have written, changes that clash among them included.
  ///
  /// One thing it reads that this version would not have written: a command
  /// on the keys another ships with, that other having nothing stored. A
  /// version from before the other command had those keys wrote it. What was
  /// chosen is kept, and the other command is left without a shortcut.
  static ShortcutBindings fromJson(Map<String, Object?> json, {required bool isMac}) {
    final defaults = ShortcutBindings.defaults(isMac: isMac);

    final savedModifiers = json['accountModifiers'];
    final accountModifiers = savedModifiers == null ? null : KeyModifiers.fromJson(savedModifiers);
    if (accountModifiers != null && !defaults.accountModifierChoices.contains(accountModifiers)) {
      throw FormatException('The saved account keys are not among those offered: $accountModifiers');
    }

    final commands = json['commands'];
    if (commands is! Map) throw FormatException('The saved commands are not a map: $commands');
    final names = {for (final command in AppCommand.values) command.name: command};
    final changed = <AppCommand, KeyCombo?>{};
    for (final MapEntry(:key, :value) in commands.entries) {
      final command = names[key];
      if (command == null) throw FormatException('No command is called "$key".');
      final combo = value == null ? null : KeyCombo.fromJson(value);
      if (combo != defaults._defaultOf(command)) changed[command] = combo;
    }
    // The keys a command was given are its own: a command that only ships
    // with them gives them up.
    final chosen = {...changed.values.nonNulls};
    for (final command in AppCommand.values) {
      if (!changed.containsKey(command) && chosen.contains(defaults._defaultOf(command))) changed[command] = null;
    }

    final bindings = ShortcutBindings._(
      isMac,
      Map.unmodifiable(changed),
      accountModifiers == defaults._command ? null : accountModifiers,
    );
    // Checked once all of them are in place, not one by one over the
    // defaults: a command may hold the keys another one gave up.
    for (final MapEntry(key: command, value: combo) in changed.entries) {
      if (combo == null) continue;
      final refused = bindings.refusal(command, combo);
      if (refused != null) throw FormatException('The saved shortcuts clash: $combo refused for $command: $refused');
    }
    return bindings;
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutBindings &&
      other.isMac == isMac &&
      other._accountModifiers == _accountModifiers &&
      mapEquals(other._changed, _changed);

  @override
  int get hashCode => Object.hash(
    isMac,
    _accountModifiers,
    Object.hashAllUnordered(_changed.entries.map((e) => Object.hash(e.key, e.value))),
  );
}
