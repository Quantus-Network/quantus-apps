import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_desktop_wallet/ui/settings/keep_running_row.dart';
import 'package:quantus_desktop_wallet/ui/settings/keyboard_shortcuts_step.dart';
import 'package:quantus_desktop_wallet/ui/settings/language_pop_up.dart';
import 'package:quantus_desktop_wallet/ui/settings/notifications_row.dart';
import 'package:quantus_desktop_wallet/ui/settings/recovery_phrase_steps.dart';
import 'package:quantus_desktop_wallet/ui/settings/reset_wallet_step.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/user_approval.dart';

/// The steps of the Settings sheet. Each but the list has a way back.
enum _Step { list, phraseWallets, phraseCaution, phraseWords, reset, shortcuts }

/// The Settings sheet: the list of settings, and the steps its rows open in
/// the same sheet (the recovery phrase, resetting the wallet, and the
/// keyboard shortcuts).
///
/// Both wallet rows hand the wallet over, so they need the system's approval
/// ([UserApproval]); where it cannot be asked for, they are unavailable and
/// say why.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  static const recoveryPhraseRowKey = Key('settings-recovery-phrase');
  static const resetRowKey = Key('settings-reset-wallet');
  static const languageKey = Key('settings-language');
  static const keyboardShortcutsRowKey = Key('settings-keyboard-shortcuts');
  static const continueKey = Key('settings-continue');
  static const cancelKey = Key('settings-cancel');
  static const hideKey = Key('settings-phrase-hide');
  static const copyKey = Key('settings-phrase-copy');
  static const doneKey = Key('settings-phrase-done');
  static const phraseGridKey = Key('settings-phrase-grid');
  static const backupCheckboxKey = Key('settings-backed-up');
  static const resetButtonKey = Key('settings-reset-button');

  static Key phraseWalletKey(int walletIndex) => ValueKey('settings-phrase-wallet-$walletIndex');

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  _Step _step = _Step.list;

  /// The wallet whose recovery phrase is being shown.
  int? _phraseWallet;

  /// The recovery phrase's words, held only while they are on screen.
  List<String>? _words;

  @override
  void initState() {
    super.initState();
    // Opened for one wallet's recovery phrase: start on its caution, and
    // clear the request once this frame is done (not while building).
    final wallet = ref.read(recoveryPhraseTargetProvider);
    if (wallet != null) {
      _phraseWallet = wallet;
      _step = _Step.phraseCaution;
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(recoveryPhraseTargetProvider.notifier).clear());
    }
  }

  void _go(_Step step) => setState(() {
    _step = step;
    if (step != _Step.phraseWords) _words = null;
  });

  void _openPhraseOf(int walletIndex) => setState(() {
    _phraseWallet = walletIndex;
    _step = _Step.phraseCaution;
  });

  /// Back one level: from a wallet's caution to the list of wallets when
  /// there is more than one, otherwise to the list of settings.
  void _back() => _go(
    _step == _Step.phraseCaution && ref.read(softwareWalletsProvider).length > 1 ? _Step.phraseWallets : _Step.list,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final words = _words;

    final (title, body) = switch (_step) {
      _Step.list => (l10n.settingsTitle, _SettingsList(onOpen: _go, onOpenPhrase: _openPhraseOf)),
      _Step.phraseWallets => (l10n.settingsRecoveryPhraseTitle, _PhraseWallets(onOpen: _openPhraseOf)),
      _Step.phraseCaution => (
        l10n.settingsRecoveryPhraseTitle,
        RecoveryPhraseCaution(
          walletIndex: _phraseWallet!,
          onCancel: _back,
          onApproved: (words) => setState(() {
            _words = words;
            _step = _Step.phraseWords;
          }),
        ),
      ),
      _Step.phraseWords when words != null => (
        l10n.settingsRecoveryPhraseTitle,
        RecoveryPhraseWords(walletIndex: _phraseWallet!, words: words, onDone: () => Navigator.of(context).pop()),
      ),
      _Step.phraseWords => throw StateError('The recovery phrase step has no words.'),
      _Step.reset => (l10n.settingsResetTitle, ResetWalletStep(onCancel: () => _go(_Step.list))),
      _Step.shortcuts => (l10n.settingsKeyboardShortcuts, const KeyboardShortcutsStep()),
    };

    final isList = _step == _Step.list;

    return SheetBackShortcut(
      onBack: isList ? null : _back,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The path names Settings, and goes back to its list.
          ShellSheetHeader(
            title: title,
            parent: isList ? null : (title: l10n.settingsTitle, onBack: () => _go(_Step.list)),
          ),
          const SizedBox(height: 18),
          // A step longer than the window scrolls within the sheet.
          Flexible(child: body),
        ],
      ),
    );
  }
}

/// The list: the wallet's rows, then the preferences.
class _SettingsList extends ConsumerStatefulWidget {
  const _SettingsList({required this.onOpen, required this.onOpenPhrase});

  final ValueChanged<_Step> onOpen;

  /// Opens the recovery phrase of the wallet at the given index.
  final ValueChanged<int> onOpenPhrase;

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
    final wallets = ref.watch(softwareWalletsProvider);

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
              subtitle:
                  note ??
                  (wallets.length > 1
                      ? l10n.desktopRecoveryPhraseWalletsSubtitle(wallets.length)
                      : l10n.settingsWalletRecoveryPhraseSubtitle),
              // One wallet goes straight to its caution; more to a list of them.
              onPressed: !canApprove
                  ? null
                  : wallets.length > 1
                  ? () => widget.onOpen(_Step.phraseWallets)
                  : () => widget.onOpenPhrase(wallets.single.walletIndex),
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
            const NotificationsRow(),
            if (supportsBackgroundMode) const KeepRunningRow(),
            SettingsRow.action(
              key: SettingsSheet.keyboardShortcutsRowKey,
              title: l10n.settingsKeyboardShortcuts,
              subtitle: l10n.settingsKeyboardShortcutsSubtitle,
              onPressed: () => widget.onOpen(_Step.shortcuts),
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

/// The software wallets, one row each, named with their accounts: the
/// recovery phrase of each can be shown. Many wallets scroll inside the sheet.
class _PhraseWallets extends ConsumerWidget {
  const _PhraseWallets({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return SingleChildScrollView(
      child: SettingsGroup(
        label: l10n.desktopRecoveryPhraseChooseWallet,
        rows: [
          for (final wallet in ref.watch(softwareWalletsProvider))
            SettingsRow.action(
              key: SettingsSheet.phraseWalletKey(wallet.walletIndex),
              title: wallet.name,
              subtitle: wallet.accounts.join(', '),
              onPressed: () => onOpen(wallet.walletIndex),
            ),
        ],
      ),
    );
  }
}
