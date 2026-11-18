import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';

const _cmd = KeyModifiers(meta: true);
const _ctrl = KeyModifiers(control: true);
const _optCmd = KeyModifiers(meta: true, alt: true);
const _ctrlAlt = KeyModifiers(control: true, alt: true);

KeyCombo _combo(LogicalKeyboardKey key, KeyModifiers modifiers) => KeyCombo(key, modifiers);

/// [bindings] as they are after being written to the settings and read.
Map<String, Object?> _stored(ShortcutBindings bindings) =>
    jsonDecode(jsonEncode(bindings.toJson())) as Map<String, Object?>;

void main() {
  const mac = ShortcutBindings.defaults(isMac: true);
  const pc = ShortcutBindings.defaults(isMac: false);

  group('the defaults', () {
    test('on the Mac use ⌘, and walk the sidebar with ⌥⌘↓ and ⌥⌘↑', () {
      expect(mac[AppCommand.receive], _combo(LogicalKeyboardKey.keyR, _cmd));
      expect(mac[AppCommand.send], _combo(LogicalKeyboardKey.keyS, _cmd));
      expect(mac[AppCommand.addAccount], _combo(LogicalKeyboardKey.keyN, _cmd));
      expect(mac[AppCommand.toggleSidebar], _combo(LogicalKeyboardKey.keyB, _cmd));
      expect(mac[AppCommand.nextSidebarItem], _combo(LogicalKeyboardKey.arrowDown, _optCmd));
      expect(mac[AppCommand.previousSidebarItem], _combo(LogicalKeyboardKey.arrowUp, _optCmd));
      expect(mac.accountModifiers, _cmd);
      expect(mac.account(0), _combo(LogicalKeyboardKey.digit1, _cmd));
      expect(mac.account(8), _combo(LogicalKeyboardKey.digit9, _cmd));
      expect(mac.account(9), isNull);
    });

    test('on Windows and Linux use Ctrl, and walk the sidebar with Ctrl+Alt+Down and Up', () {
      expect(pc[AppCommand.receive], _combo(LogicalKeyboardKey.keyR, _ctrl));
      expect(pc[AppCommand.send], _combo(LogicalKeyboardKey.keyS, _ctrl));
      expect(pc[AppCommand.addAccount], _combo(LogicalKeyboardKey.keyN, _ctrl));
      expect(pc[AppCommand.toggleSidebar], _combo(LogicalKeyboardKey.keyB, _ctrl));
      expect(pc[AppCommand.nextSidebarItem], _combo(LogicalKeyboardKey.arrowDown, _ctrlAlt));
      expect(pc[AppCommand.previousSidebarItem], _combo(LogicalKeyboardKey.arrowUp, _ctrlAlt));
      expect(pc.accountModifiers, _ctrl);
      expect(pc.account(2), _combo(LogicalKeyboardKey.digit3, _ctrl));
    });

    test('the fixed shortcuts are the system\'s: Settings and Close Window', () {
      expect(mac.settings, _combo(LogicalKeyboardKey.comma, _cmd));
      expect(mac.closeWindow, _combo(LogicalKeyboardKey.keyW, _cmd));
      expect(pc.settings, _combo(LogicalKeyboardKey.comma, _ctrl));
      expect(pc.closeWindow, _combo(LogicalKeyboardKey.keyW, _ctrl));
    });
  });

  group('a new shortcut', () {
    test('is taken when nothing else has it', () {
      final combo = _combo(LogicalKeyboardKey.keyJ, _cmd);

      expect(mac.refusal(AppCommand.nextSidebarItem, combo), isNull);
      expect(mac.withShortcut(AppCommand.nextSidebarItem, combo)[AppCommand.nextSidebarItem], combo);
    });

    test('is taken when it is the command\'s own', () {
      expect(mac.refusal(AppCommand.receive, _combo(LogicalKeyboardKey.keyR, _cmd)), isNull);
    });

    test('is refused when another command has it, naming that command', () {
      final refusal = mac.refusal(AppCommand.nextSidebarItem, _combo(LogicalKeyboardKey.keyR, _cmd));

      expect(refusal, const UsedByCommand(AppCommand.receive));
      expect(
        () => mac.withShortcut(AppCommand.nextSidebarItem, _combo(LogicalKeyboardKey.keyR, _cmd)),
        throwsArgumentError,
      );
    });

    test('is refused when it is the account keys with a digit', () {
      expect(mac.refusal(AppCommand.send, _combo(LogicalKeyboardKey.digit4, _cmd)), const UsedByAccounts());
      expect(pc.refusal(AppCommand.send, _combo(LogicalKeyboardKey.digit1, _ctrl)), const UsedByAccounts());
      // A digit with other keys is free.
      expect(mac.refusal(AppCommand.send, _combo(LogicalKeyboardKey.digit4, _optCmd)), isNull);
    });

    test('is refused when the system keeps it, naming the system\'s command', () {
      final macKept = {
        _combo(LogicalKeyboardKey.keyQ, _cmd): SystemCommand.quit,
        _combo(LogicalKeyboardKey.keyW, _cmd): SystemCommand.closeWindow,
        _combo(LogicalKeyboardKey.comma, _cmd): SystemCommand.settings,
        _combo(LogicalKeyboardKey.keyH, _cmd): SystemCommand.hide,
        _combo(LogicalKeyboardKey.keyH, _optCmd): SystemCommand.hideOthers,
        _combo(LogicalKeyboardKey.keyM, _cmd): SystemCommand.minimize,
        _combo(LogicalKeyboardKey.keyF, const KeyModifiers(meta: true, control: true)): SystemCommand.fullScreen,
        _combo(LogicalKeyboardKey.keyX, _cmd): SystemCommand.cut,
        _combo(LogicalKeyboardKey.keyC, _cmd): SystemCommand.copy,
        _combo(LogicalKeyboardKey.keyV, _cmd): SystemCommand.paste,
        _combo(LogicalKeyboardKey.keyA, _cmd): SystemCommand.selectAll,
        _combo(LogicalKeyboardKey.keyZ, _cmd): SystemCommand.undo,
        _combo(LogicalKeyboardKey.keyZ, const KeyModifiers(meta: true, shift: true)): SystemCommand.redo,
      };
      final pcKept = {
        _combo(LogicalKeyboardKey.f4, const KeyModifiers(alt: true)): SystemCommand.quit,
        _combo(LogicalKeyboardKey.keyW, _ctrl): SystemCommand.closeWindow,
        _combo(LogicalKeyboardKey.comma, _ctrl): SystemCommand.settings,
        _combo(LogicalKeyboardKey.keyX, _ctrl): SystemCommand.cut,
        _combo(LogicalKeyboardKey.keyC, _ctrl): SystemCommand.copy,
        _combo(LogicalKeyboardKey.keyV, _ctrl): SystemCommand.paste,
        _combo(LogicalKeyboardKey.keyA, _ctrl): SystemCommand.selectAll,
        _combo(LogicalKeyboardKey.keyZ, _ctrl): SystemCommand.undo,
        _combo(LogicalKeyboardKey.keyY, _ctrl): SystemCommand.redo,
      };

      for (final MapEntry(key: combo, value: system) in macKept.entries) {
        expect(mac.refusal(AppCommand.send, combo), KeptForSystem(system), reason: '$combo on the Mac');
      }
      for (final MapEntry(key: combo, value: system) in pcKept.entries) {
        expect(pc.refusal(AppCommand.send, combo), KeptForSystem(system), reason: '$combo on Windows and Linux');
      }
    });

    test('is refused without ⌘, ⌥ or ⌃ on the Mac, and without Ctrl or Alt elsewhere', () {
      for (final bindings in [mac, pc]) {
        expect(
          bindings.refusal(AppCommand.send, _combo(LogicalKeyboardKey.keyJ, const KeyModifiers())),
          const NeedsModifier(),
        );
        expect(
          bindings.refusal(AppCommand.send, _combo(LogicalKeyboardKey.keyJ, const KeyModifiers(shift: true))),
          const NeedsModifier(),
        );
      }
      expect(mac.refusal(AppCommand.send, _combo(LogicalKeyboardKey.keyJ, const KeyModifiers(control: true))), isNull);
      expect(mac.refusal(AppCommand.send, _combo(LogicalKeyboardKey.keyJ, const KeyModifiers(alt: true))), isNull);
      expect(pc.refusal(AppCommand.send, _combo(LogicalKeyboardKey.keyJ, const KeyModifiers(alt: true))), isNull);
    });

    test('is refused with the Windows or Super key on Windows and Linux', () {
      expect(
        pc.refusal(AppCommand.send, _combo(LogicalKeyboardKey.keyJ, const KeyModifiers(meta: true, control: true))),
        const UsesSystemKey(),
      );
    });

    test('can be no shortcut at all', () {
      final removed = mac.withShortcut(AppCommand.send, null);

      expect(removed[AppCommand.send], isNull);
      // Its old keys are free for another command.
      expect(removed.refusal(AppCommand.receive, _combo(LogicalKeyboardKey.keyS, _cmd)), isNull);
    });
  });

  group('the account keys', () {
    test('offer ⌘, ⌃ and ⌥⌘ on the Mac, and Ctrl, Alt and Ctrl+Alt elsewhere', () {
      expect(mac.accountModifierChoices, [_cmd, _ctrl, _optCmd]);
      expect(pc.accountModifierChoices, [_ctrl, const KeyModifiers(alt: true), _ctrlAlt]);
    });

    test('change every account shortcut', () {
      final changed = mac.withAccountModifiers(_optCmd);

      expect(changed.accountModifiers, _optCmd);
      expect(changed.account(1), _combo(LogicalKeyboardKey.digit2, _optCmd));
      // ⌘ with a digit is free again.
      expect(changed.refusal(AppCommand.send, _combo(LogicalKeyboardKey.digit2, _cmd)), isNull);
    });

    test('are refused when a command has those keys with a digit, naming it', () {
      final bindings = mac.withShortcut(AppCommand.send, _combo(LogicalKeyboardKey.digit5, _optCmd));

      expect(bindings.accountModifiersRefusal(_optCmd), const UsedByCommand(AppCommand.send));
      expect(() => bindings.withAccountModifiers(_optCmd), throwsArgumentError);
      expect(bindings.accountModifiersRefusal(_ctrl), isNull);
    });
  });

  group('saved', () {
    test('keep only what was changed, and read back the same', () {
      final changed = mac
          .withShortcut(AppCommand.nextSidebarItem, _combo(LogicalKeyboardKey.keyJ, _cmd))
          .withShortcut(AppCommand.send, null)
          .withAccountModifiers(_ctrl);

      final json = changed.toJson();

      expect((json['commands']! as Map).keys, unorderedEquals(['nextSidebarItem', 'send']));
      expect(ShortcutBindings.fromJson(json, isMac: true), changed);
    });

    test('with nothing changed read back as the defaults', () {
      expect(ShortcutBindings.fromJson(pc.toJson(), isMac: false), pc);
    });

    test('in a shape this app did not write fail to read', () {
      expect(() => ShortcutBindings.fromJson({'commands': 'no'}, isMac: true), throwsFormatException);
      expect(
        () => ShortcutBindings.fromJson({
          'commands': {'noSuchCommand': null},
        }, isMac: true),
        throwsFormatException,
      );
      expect(
        () => ShortcutBindings.fromJson({
          'commands': {
            'send': {'key': -1, 'meta': true, 'control': false, 'alt': false, 'shift': false},
          },
        }, isMac: true),
        throwsFormatException,
      );
    });

    test('that clash with each other fail to read', () {
      final json = {
        'commands': {'send': const KeyCombo(LogicalKeyboardKey.keyR, _cmd).toJson()},
      };

      expect(() => ShortcutBindings.fromJson(json, isMac: true), throwsFormatException);
    });

    test('two commands that took each other\'s keys read back the same', () {
      for (final (bindings, command) in [(mac, _cmd), (pc, _ctrl)]) {
        final swapped = bindings
            .withShortcut(AppCommand.receive, _combo(LogicalKeyboardKey.keyJ, command))
            .withShortcut(AppCommand.send, _combo(LogicalKeyboardKey.keyR, command))
            .withShortcut(AppCommand.receive, _combo(LogicalKeyboardKey.keyS, command));

        final read = ShortcutBindings.fromJson(_stored(swapped), isMac: bindings.isMac);

        expect(read, swapped);
        expect(read[AppCommand.receive], _combo(LogicalKeyboardKey.keyS, command));
        expect(read[AppCommand.send], _combo(LogicalKeyboardKey.keyR, command));
      }
    });

    test('whatever a run of allowed changes ends on reads back the same', () {
      const keys = [
        LogicalKeyboardKey.keyR,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.keyN,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit9,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
      ];
      for (final start in [mac, pc]) {
        final random = Random(7);
        final modifiers = [...start.accountModifierChoices, const KeyModifiers(control: true, shift: true)];
        var bindings = start;
        var changes = 0;
        for (var step = 0; step < 2000; step++) {
          final command = AppCommand.values[random.nextInt(AppCommand.values.length)];
          switch (random.nextInt(8)) {
            case 0:
              bindings = bindings.withShortcut(command, null);
            case 1:
              final choice = start.accountModifierChoices[random.nextInt(start.accountModifierChoices.length)];
              if (bindings.accountModifiersRefusal(choice) != null) continue;
              bindings = bindings.withAccountModifiers(choice);
            default:
              final combo = _combo(keys[random.nextInt(keys.length)], modifiers[random.nextInt(modifiers.length)]);
              if (bindings.refusal(command, combo) != null) continue;
              bindings = bindings.withShortcut(command, combo);
          }
          changes++;

          expect(
            ShortcutBindings.fromJson(_stored(bindings), isMac: start.isMac),
            bindings,
            reason: 'after change $changes: ${bindings.toJson()}',
          );
        }
        expect(changes, greaterThan(500));
      }
    });

    test('that this app would have refused fail to read', () {
      Map<String, Object?> saved(Map<String, KeyCombo> commands, {KeyModifiers? accountModifiers}) => {
        'commands': {for (final MapEntry(:key, :value) in commands.entries) key: value.toJson()},
        'accountModifiers': ?accountModifiers?.toJson(),
      };

      for (final (why, json) in [
        (
          'two commands with the same keys',
          saved({'receive': _combo(LogicalKeyboardKey.keyJ, _cmd), 'send': _combo(LogicalKeyboardKey.keyJ, _cmd)}),
        ),
        ('a command with keys the system keeps', saved({'send': _combo(LogicalKeyboardKey.keyQ, _cmd)})),
        ('a command with the account keys and a digit', saved({'send': _combo(LogicalKeyboardKey.digit1, _cmd)})),
        (
          'a command with the changed account keys and a digit',
          saved({'send': _combo(LogicalKeyboardKey.digit1, _ctrl)}, accountModifiers: _ctrl),
        ),
        ('a command with no modifier', saved({'send': _combo(LogicalKeyboardKey.keyJ, const KeyModifiers())})),
        ('account keys that are not offered', saved({}, accountModifiers: const KeyModifiers(shift: true))),
      ]) {
        expect(() => ShortcutBindings.fromJson(json, isMac: true), throwsFormatException, reason: why);
      }
    });

    test('with a default written out read back as the defaults', () {
      final json = {
        'commands': {'send': _combo(LogicalKeyboardKey.keyS, _cmd).toJson()},
        'accountModifiers': _cmd.toJson(),
      };

      expect(ShortcutBindings.fromJson(json, isMac: true), mac);
    });
  });
}
