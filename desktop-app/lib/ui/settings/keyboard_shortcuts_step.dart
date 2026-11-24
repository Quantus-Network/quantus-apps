import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/providers/shortcut_bindings_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/notice_box.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/shortcut_recorder.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// Settings › Keyboard Shortcuts: each command the person can give other
/// keys, the keys that go to an account, and Restore Defaults. Settings,
/// Close Window and Quit keep the system's keys.
///
/// A shortcut records new keys when clicked; keys another command, an
/// account or the system has are refused, naming who has them, and the
/// shortcut waits for others.
class KeyboardShortcutsStep extends ConsumerStatefulWidget {
  const KeyboardShortcutsStep({super.key});

  static Key shortcutKey(AppCommand command) => Key('shortcut-${command.name}');
  static const accountKeysKey = Key('shortcut-account-keys');
  static const restoreKey = Key('shortcut-restore-defaults');

  @override
  ConsumerState<KeyboardShortcutsStep> createState() => _KeyboardShortcutsStepState();
}

class _KeyboardShortcutsStepState extends ConsumerState<KeyboardShortcutsStep> {
  /// The command whose shortcut waits for new keys.
  AppCommand? _recording;

  /// Keys pressed for [_recording] that were refused, and why.
  KeyCombo? _refused;
  String? _refusal;

  /// Why the account keys chosen last were refused.
  String? _accountRefusal;

  /// Why the last change could not be saved.
  String? _saveError;

  late final RecordingShortcutNotifier _recordingNotifier = ref.read(isRecordingShortcutProvider.notifier);

  @override
  void dispose() {
    // The menus get their keys back. Not now: providers cannot change while
    // the tree is being taken down.
    if (_recording != null) scheduleMicrotask(_recordingNotifier.stop);
    super.dispose();
  }

  void _start(AppCommand command) {
    setState(() {
      _recording = command;
      _refused = null;
      _refusal = null;
    });
    _recordingNotifier.start();
  }

  void _stop() {
    if (_recording == null) return;
    setState(() {
      _recording = null;
      _refused = null;
      _refusal = null;
    });
    _recordingNotifier.stop();
  }

  /// [command]'s shortcut gave up waiting: Escape, or the keyboard's focus
  /// left it. When the focus left for another shortcut, that one waits by
  /// now and is left to.
  void _cancel(AppCommand command) {
    if (_recording == command) _stop();
  }

  void _onKeys(AppCommand command, KeyCombo combo) {
    final l10n = ref.read(l10nProvider);
    final refusal = ref.read(shortcutBindingsProvider).bindings.refusal(command, combo);
    if (refusal != null) {
      setState(() {
        _refused = combo;
        _refusal = _refusalText(l10n, refusal, isMac: ref.read(shortcutBindingsProvider).bindings.isMac);
      });
      return;
    }
    _stop();
    unawaited(_save(() => ref.read(shortcutBindingsProvider.notifier).setShortcut(command, combo)));
  }

  void _remove(AppCommand command) {
    _stop();
    unawaited(_save(() => ref.read(shortcutBindingsProvider.notifier).setShortcut(command, null)));
  }

  void _chooseAccountKeys(KeyModifiers modifiers) {
    final refusal = ref.read(shortcutBindingsProvider).bindings.accountModifiersRefusal(modifiers);
    if (refusal != null) {
      setState(() => _accountRefusal = _modifierRefusalText(ref.read(l10nProvider), refusal));
      return;
    }
    setState(() => _accountRefusal = null);
    unawaited(_save(() => ref.read(shortcutBindingsProvider.notifier).setAccountModifiers(modifiers)));
  }

  void _restoreDefaults() {
    _stop();
    setState(() => _accountRefusal = null);
    unawaited(_save(() => ref.read(shortcutBindingsProvider.notifier).restoreDefaults()));
  }

  Future<void> _save(Future<void> Function() change) async {
    setState(() => _saveError = null);
    try {
      await change();
    } catch (e) {
      quantusPrint('Saving a keyboard shortcut failed: $e');
      if (mounted) setState(() => _saveError = ref.read(l10nProvider).desktopShortcutsSaveFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final settings = ref.watch(shortcutBindingsProvider);
    final bindings = settings.bindings;
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final saveError = _saveError;

    Widget row(AppCommand command) {
      final isRecording = _recording == command;
      final name = commandName(l10n, command);
      return _Row(
        title: name,
        note: isRecording ? (_refusal ?? l10n.desktopShortcutsRecordingHint) : null,
        isWarning: isRecording && _refusal != null,
        trailingInset: ShortcutRecorder.inset,
        trailing: ShortcutRecorder(
          key: KeyboardShortcutsStep.shortcutKey(command),
          combo: bindings[command],
          isMac: bindings.isMac,
          isRecording: isRecording,
          refused: isRecording ? _refused : null,
          noneLabel: l10n.desktopShortcutsNone,
          recordingLabel: l10n.desktopShortcutsRecording,
          semanticLabel: name,
          onStart: () => _start(command),
          onKeys: (combo) => _onKeys(command, combo),
          onCancel: () => _cancel(command),
          onRemove: () => _remove(command),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings.savedWereUnreadable) ...[
          NoticeBox(
            tone: colors.semanticSand,
            child: Text(l10n.desktopShortcutsUnreadable, style: text.body.copyWith(color: colors.textContent)),
          ),
          const SizedBox(height: 18),
        ],
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  label: l10n.desktopMenuAccount,
                  rows: [
                    row(AppCommand.receive),
                    row(AppCommand.send),
                    row(AppCommand.propose),
                    row(AppCommand.swap),
                    row(AppCommand.addAccount),
                    row(AppCommand.getInfo),
                    row(AppCommand.copyAddress),
                    _Row(
                      title: l10n.desktopShortcutsAccounts,
                      note: _accountRefusal,
                      isWarning: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopUpButton<KeyModifiers>(
                            key: KeyboardShortcutsStep.accountKeysKey,
                            semanticLabel: l10n.desktopShortcutsAccounts,
                            items: [
                              for (final choice in bindings.accountModifierChoices)
                                PopUpItem(choice, modifiersName(choice, isMac: bindings.isMac)),
                            ],
                            value: bindings.accountModifiers,
                            onSelected: _chooseAccountKeys,
                          ),
                          const SizedBox(width: 8),
                          Text('+  1 … 9', style: text.body.copyWith(color: colors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SettingsGroup(
                  label: l10n.desktopMenuView,
                  rows: [
                    row(AppCommand.toggleSidebar),
                    row(AppCommand.nextSidebarItem),
                    row(AppCommand.previousSidebarItem),
                    row(AppCommand.refresh),
                  ],
                ),
                const SizedBox(height: 18),
                if (saveError != null) ...[
                  Text(saveError, style: text.body.copyWith(color: colors.semanticEmber)),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.desktopShortcutsFixedNote,
                        style: text.caption.copyWith(color: colors.textMuted2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SheetButton(
                      key: KeyboardShortcutsStep.restoreKey,
                      label: l10n.desktopShortcutsRestoreDefaults,
                      kind: SheetButtonKind.secondary,
                      onTap: _restoreDefaults,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A row of the list: the command's name, its keys at the end, and a line
/// under them while it records or after a refusal.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.trailing, this.trailingInset = 0, this.note, this.isWarning = false});

  final String title;
  final Widget trailing;

  /// How far [trailing]'s content sits inside its own edge; the row moves it
  /// out by as much, so the content ends on the row's content edge.
  final double trailingInset;

  final String? note;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final note = this.note;

    const edge = 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(edge, 8, edge - trailingInset, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: text.body.copyWith(color: colors.textContent)),
              ),
              const SizedBox(width: 16),
              trailing,
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(right: trailingInset),
              child: Text(
                note,
                textAlign: TextAlign.end,
                style: text.caption.copyWith(color: isWarning ? colors.semanticEmber : colors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What Settings and the refusals call [command].
String commandName(AppLocalizations l10n, AppCommand command) => switch (command) {
  AppCommand.receive => sheetTitle(l10n, ShellSheet.receive),
  AppCommand.send => sheetTitle(l10n, ShellSheet.send),
  AppCommand.propose => sheetTitle(l10n, ShellSheet.propose),
  AppCommand.swap => sheetTitle(l10n, ShellSheet.swap),
  AppCommand.addAccount => l10n.desktopMenuNewAccount,
  AppCommand.getInfo => l10n.desktopAccountGetInfo,
  AppCommand.copyAddress => l10n.desktopAccountCopyAddress,
  AppCommand.toggleSidebar => l10n.desktopShortcutsToggleSidebar,
  AppCommand.nextSidebarItem => l10n.desktopMenuNextSidebarItem,
  AppCommand.previousSidebarItem => l10n.desktopMenuPreviousSidebarItem,
  AppCommand.refresh => l10n.desktopMenuRefresh,
};

String _systemName(AppLocalizations l10n, SystemCommand command) => switch (command) {
  SystemCommand.settings => l10n.settingsTitle,
  SystemCommand.closeWindow => l10n.desktopMenuCloseWindow,
  SystemCommand.quit => l10n.desktopSystemQuit,
  SystemCommand.hide => l10n.desktopSystemHide,
  SystemCommand.hideOthers => l10n.desktopSystemHideOthers,
  SystemCommand.minimize => l10n.desktopSystemMinimize,
  SystemCommand.fullScreen => l10n.desktopSystemFullScreen,
  SystemCommand.cut => l10n.desktopSystemCut,
  SystemCommand.copy => l10n.desktopSystemCopy,
  SystemCommand.paste => l10n.desktopSystemPaste,
  SystemCommand.selectAll => l10n.desktopSystemSelectAll,
  SystemCommand.undo => l10n.desktopSystemUndo,
  SystemCommand.redo => l10n.desktopSystemRedo,
};

/// Why keys were not taken for a command.
String _refusalText(AppLocalizations l10n, ShortcutRefusal refusal, {required bool isMac}) => switch (refusal) {
  UsedByCommand(:final command) => l10n.desktopShortcutsUsedBy(commandName(l10n, command)),
  UsedByAccounts() => l10n.desktopShortcutsUsedBy(l10n.desktopShortcutsAccounts),
  KeptForSystem(:final command) => l10n.desktopShortcutsKeptFor(_systemName(l10n, command)),
  NeedsModifier() => isMac ? l10n.desktopShortcutsNeedsModifierMac : l10n.desktopShortcutsNeedsModifierPc,
  UsesSystemKey() => l10n.desktopShortcutsSystemKey,
  KeyNotForMenuBar() => l10n.desktopShortcutsKeyNotForMenuBar,
};

/// Why account keys were not taken.
String _modifierRefusalText(AppLocalizations l10n, ShortcutRefusal refusal) => switch (refusal) {
  UsedByCommand(:final command) => l10n.desktopShortcutsModifierUsedBy(commandName(l10n, command)),
  _ => throw StateError('Account keys cannot be refused for $refusal.'),
};

/// The modifier keys [modifiers] by their names on the keyboard, for the
/// account keys' pop-up: "Option + Command" on the Mac, "Ctrl + Alt" elsewhere.
String modifiersName(KeyModifiers modifiers, {required bool isMac}) => [
  if (isMac) ...[
    if (modifiers.control) 'Control',
    if (modifiers.alt) 'Option',
    if (modifiers.shift) 'Shift',
    if (modifiers.meta) 'Command',
  ] else ...[
    if (modifiers.control) 'Ctrl',
    if (modifiers.alt) 'Alt',
    if (modifiers.shift) 'Shift',
  ],
].join(' + ');
