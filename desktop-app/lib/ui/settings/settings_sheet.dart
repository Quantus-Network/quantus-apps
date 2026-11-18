import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_desktop_wallet/ui/settings/language_pop_up.dart';
import 'package:quantus_desktop_wallet/ui/settings/recovery_phrase_steps.dart';
import 'package:quantus_desktop_wallet/ui/settings/reset_wallet_step.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/user_approval.dart';

/// The steps of the Settings sheet. Each but the list has a way back to it.
enum _Step { list, phraseCaution, phraseWords, reset }

/// The Settings sheet: the list of settings, and the steps its wallet rows
/// open in the same sheet (the recovery phrase, and resetting the wallet).
///
/// Both wallet rows hand the wallet over, so they need the system's approval
/// ([UserApproval]); where it cannot be asked for, they are unavailable and
/// say why.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  static const recoveryPhraseRowKey = Key('settings-recovery-phrase');
  static const resetRowKey = Key('settings-reset-wallet');
  static const languageKey = Key('settings-language');
  static const continueKey = Key('settings-continue');
  static const cancelKey = Key('settings-cancel');
  static const hideKey = Key('settings-phrase-hide');
  static const copyKey = Key('settings-phrase-copy');
  static const doneKey = Key('settings-phrase-done');
  static const phraseGridKey = Key('settings-phrase-grid');
  static const backupCheckboxKey = Key('settings-backed-up');
  static const resetButtonKey = Key('settings-reset-button');

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  _Step _step = _Step.list;

  /// The recovery phrase's words, held only while they are on screen.
  List<String>? _words;

  void _go(_Step step) => setState(() {
    _step = step;
    if (step != _Step.phraseWords) _words = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final words = _words;

    final (title, body) = switch (_step) {
      _Step.list => (l10n.settingsTitle, _SettingsList(onOpen: _go)),
      _Step.phraseCaution => (
        l10n.settingsRecoveryPhraseTitle,
        RecoveryPhraseCaution(
          onCancel: () => _go(_Step.list),
          onApproved: (words) => setState(() {
            _words = words;
            _step = _Step.phraseWords;
          }),
        ),
      ),
      _Step.phraseWords when words != null => (
        l10n.settingsRecoveryPhraseTitle,
        RecoveryPhraseWords(words: words, onDone: () => Navigator.of(context).pop()),
      ),
      _Step.phraseWords => throw StateError('The recovery phrase step has no words.'),
      _Step.reset => (l10n.settingsResetTitle, ResetWalletStep(onCancel: () => _go(_Step.list))),
    };

    final onBack = _step == _Step.list ? null : () => _go(_Step.list);

    return SheetBackShortcut(
      onBack: onBack,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellSheetHeader(title: title, parent: onBack == null ? null : (title: l10n.settingsTitle, onBack: onBack)),
          const SizedBox(height: 18),
          body,
        ],
      ),
    );
  }
}

/// The list: the wallet's rows, then the preferences.
class _SettingsList extends ConsumerStatefulWidget {
  const _SettingsList({required this.onOpen});

  final ValueChanged<_Step> onOpen;

  @override
  ConsumerState<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends ConsumerState<_SettingsList> {
  /// Why the language could not be changed, if it could not.
  String? _languageError;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final availability = ref.watch(approvalAvailabilityProvider);
    final canApprove = availability.value == ApprovalAvailability.available;
    // Said in place of each wallet row's own line when it cannot be used.
    final note = switch (availability) {
      AsyncData(:final value) => approvalUnavailableNote(l10n, value),
      AsyncError(:final error) => l10n.desktopApprovalFailed('$error'),
      _ => null,
    };
    final languageError = _languageError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: l10n.settingsWalletTitle,
          rows: [
            SettingsRow.action(
              key: SettingsSheet.recoveryPhraseRowKey,
              title: l10n.settingsWalletRecoveryPhrase,
              subtitle: note ?? l10n.settingsWalletRecoveryPhraseSubtitle,
              onPressed: canApprove ? () => widget.onOpen(_Step.phraseCaution) : null,
            ),
            SettingsRow.action(
              key: SettingsSheet.resetRowKey,
              title: l10n.settingsWalletReset,
              subtitle: note ?? l10n.settingsWalletResetSubtitle,
              isDestructive: true,
              onPressed: canApprove ? () => widget.onOpen(_Step.reset) : null,
            ),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          label: l10n.settingsPreferencesTitle,
          rows: [
            SettingsRow.control(
              title: l10n.settingsPreferencesLanguage,
              subtitle: l10n.settingsPreferencesLanguageSubtitle,
              trailing: LanguagePopUp(
                key: SettingsSheet.languageKey,
                onFailed: (e) {
                  quantusPrint('Saving the chosen language failed: $e');
                  // The list may be gone by now: the sheet closed, or a step opened.
                  if (mounted) setState(() => _languageError = l10n.settingsLanguageError('$e'));
                },
              ),
            ),
          ],
        ),
        if (languageError != null) ...[
          const SizedBox(height: 12),
          Text(languageError, style: context.themeTextV3.body.copyWith(color: context.colorsV3.semanticEmber)),
        ],
      ],
    );
  }
}
