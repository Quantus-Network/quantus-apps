import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/accounts/delete_wallet_step.dart';
import 'package:quantus_desktop_wallet/ui/components/inline_name_field.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/settings/recovery_phrase_steps.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_caution.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/account_menu.dart';

/// The Info sheet ("Get Info"): an account's name, which can be typed over,
/// its address over its checkphrase, and what applies to its wallet. A
/// multisig shows its threshold and signers instead, the encrypted account
/// its inner hash. It is about the account it was opened for
/// ([accountInfoTargetProvider]), which need not be the active one, and
/// closes if that account goes.
class AccountInfoSheet extends ConsumerStatefulWidget {
  const AccountInfoSheet({super.key});

  static const nameFieldKey = Key('account-info-name');
  static const copyAddressKey = Key('account-info-copy-address');
  static const copyInnerHashKey = Key('account-info-copy-inner-hash');
  static const copyCheckphraseKey = Key('account-info-copy-checkphrase');
  static const shareAddressKey = Key('account-info-share-address');
  static const shareInnerHashKey = Key('account-info-share-inner-hash');
  static const recoveryPhraseRowKey = Key('account-info-recovery-phrase');
  static const disconnectRowKey = Key('account-info-disconnect');
  static const disconnectButtonKey = Key('account-info-disconnect-button');
  static const disconnectCancelKey = Key('account-info-disconnect-cancel');
  static const backedUpKey = Key('account-info-backed-up');

  static Key signerKey(String accountId) => ValueKey('account-info-signer-$accountId');

  @override
  ConsumerState<AccountInfoSheet> createState() => _AccountInfoSheetState();
}

/// The steps of the Info sheet. Each but the info has a way back to it.
enum _Step { info, disconnect, phraseCaution, phraseWords }

class _AccountInfoSheetState extends ConsumerState<AccountInfoSheet> {
  /// Read once: the sheet stays on the account it opened for.
  late final AccountInfoTarget _target =
      ref.read(accountInfoTargetProvider) ?? (throw StateError('The Info sheet opened without an account'));

  late _Step _step = switch (_target.start) {
    AccountInfoStart.disconnect => _Step.disconnect,
    AccountInfoStart.recoveryPhrase => _Step.phraseCaution,
    AccountInfoStart.info || AccountInfoStart.rename => _Step.info,
  };

  /// The recovery phrase's words, held only while they are on screen.
  List<String>? _words;

  /// Opened by Rename…: the name is ready to be typed over.
  late final bool _focusName = _target.start == AccountInfoStart.rename;

  bool _isClosing = false;

  void _go(_Step step) => setState(() {
    _step = step;
    if (step != _Step.phraseWords) _words = null;
  });

  /// The account was disconnected here: the sheet closes on it.
  void _disconnected() {
    _isClosing = true;
    Navigator.of(context).maybePop();
  }

  /// What the sheet last showed. While the accounts are read again after a
  /// change they are not known, and the sheet keeps to these meanwhile.
  BaseAccount? _account;
  List<Account> _accounts = const [];
  String? _wallet;

  /// The account is gone (disconnected elsewhere): the sheet goes with it,
  /// once the frame that found out is done.
  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    // A window that comes back must not show the phrase without asking again.
    ref.listen<bool>(windowClosedProvider, (_, isClosed) {
      if (isClosed && (_step == _Step.phraseCaution || _step == _Step.phraseWords)) _go(_Step.info);
    });
    final l10n = ref.watch(l10nProvider);
    final id = _target.accountId;
    final accounts = ref.watch(accountsProvider).value;
    final multisigs = ref.watch(multisigAccountsProvider).value;
    if (accounts != null && multisigs != null) {
      final account =
          accounts.where((a) => a.accountId == id).firstOrNull ?? multisigs.where((m) => m.accountId == id).firstOrNull;
      if (account == null) {
        _close();
      } else {
        _account = account;
        _accounts = accounts;
        if (account is Account) _wallet = ref.watch(walletLabelProvider(account.walletIndex)) ?? _wallet;
      }
    }
    final account = _account;
    if (account == null) return const SizedBox.shrink();

    final infoTitle = account is MultisigAccount ? l10n.desktopMultisigInfoTitle : l10n.desktopAccountInfoTitle;
    void toDisconnect() => _go(_Step.disconnect);
    void toPhrase() => _go(_Step.phraseCaution);
    void back() => _go(_Step.info);
    final words = _words;

    final (String title, Widget body) = switch (_step) {
      _Step.info => (
        infoTitle,
        switch (account) {
          MultisigAccount() => _MultisigInfo(
            multisig: account,
            accounts: _accounts,
            focusName: _focusName,
            onDisconnect: toDisconnect,
            l10n: l10n,
          ),
          Account(accountType: AccountType.encrypted) => _EncryptedInfo(account: account, l10n: l10n),
          Account() => _AccountInfo(
            account: account,
            accounts: _accounts,
            wallet: _wallet!,
            focusName: _focusName,
            onRecoveryPhrase: toPhrase,
            onDisconnect: toDisconnect,
            l10n: l10n,
          ),
          _ => throw StateError('${account.accountId} has no Info sheet'),
        },
      ),
      _Step.phraseCaution => (
        l10n.settingsRecoveryPhraseTitle,
        RecoveryPhraseCaution(
          walletIndex: (account as Account).walletIndex,
          onCancel: back,
          onApproved: (words) => setState(() {
            _words = words;
            _step = _Step.phraseWords;
          }),
        ),
      ),
      _Step.phraseWords when words != null => (
        l10n.settingsRecoveryPhraseTitle,
        RecoveryPhraseWords(
          walletIndex: (account as Account).walletIndex,
          words: words,
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
      _Step.phraseWords => throw StateError('The recovery phrase step has no words.'),
      _Step.disconnect => (
        l10n.desktopDisconnectTitle,
        _DisconnectStep(
          account: account,
          accounts: _accounts,
          wallet: account is Account ? _wallet : null,
          onCancel: back,
          onDisconnected: _disconnected,
          l10n: l10n,
        ),
      ),
    };
    final onBack = _step == _Step.info ? null : back;

    return SheetBackShortcut(
      onBack: onBack,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellSheetHeader(
            title: title,
            account: account,
            parent: onBack == null ? null : (title: infoTitle, onBack: onBack),
          ),
          const SizedBox(height: 18),
          // Longer than the window, it scrolls within the sheet.
          Flexible(child: SingleChildScrollView(child: body)),
        ],
      ),
    );
  }
}

/// Disconnecting: the caution for what goes, then Disconnect. The last
/// account of a wallet takes the wallet and its recovery phrase, as
/// [DeleteWalletStep] has it: after a tick that the phrase is backed up, and
/// the system's approval.
class _DisconnectStep extends ConsumerStatefulWidget {
  const _DisconnectStep({
    required this.account,
    required this.accounts,
    required this.wallet,
    required this.onCancel,
    required this.onDisconnected,
    required this.l10n,
  });

  final BaseAccount account;
  final List<Account> accounts;

  /// What the account's wallet is called; null for a multisig.
  final String? wallet;
  final VoidCallback onCancel;
  final VoidCallback onDisconnected;
  final AppLocalizations l10n;

  @override
  ConsumerState<_DisconnectStep> createState() => _DisconnectStepState();
}

class _DisconnectStepState extends ConsumerState<_DisconnectStep> {
  bool _isBusy = false;
  String? _error;

  /// How the account goes; null for a multisig.
  late final DisconnectPlan? _plan = switch (widget.account) {
    final Account account =>
      disconnectPlanOf(account, widget.accounts) ?? (throw StateError('${account.accountId} cannot be disconnected')),
    _ => null,
  };

  Future<void> _disconnect() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref.read(accountManagerProvider).disconnect(widget.account);
    } catch (e) {
      quantusPrint('Disconnecting ${widget.account.accountId} failed: $e');
      if (mounted) {
        setState(() {
          _isBusy = false;
          _error = widget.l10n.accountMenuDisconnectError;
        });
      }
      return;
    }
    if (mounted) widget.onDisconnected();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final name = widget.account.name;
    final wallet = widget.wallet;

    final caution = switch (_plan) {
      DisconnectWallet() => null,
      null => SettingsCaution(
        eyebrow: l10n.desktopDisconnectMultisigEyebrow,
        headline: l10n.desktopDisconnectHeadline(name),
        lines: [l10n.desktopDisconnectMultisigLine1(name), l10n.desktopDisconnectMultisigLine2],
      ),
      DisconnectHardware() => SettingsCaution(
        eyebrow: l10n.desktopDisconnectHardwareEyebrow,
        headline: l10n.desktopDisconnectHeadline(name),
        lines: [l10n.desktopDisconnectAccountLine1(name), l10n.desktopDisconnectHardwareLine2],
      ),
      DisconnectAccount() => SettingsCaution(
        eyebrow: l10n.desktopDisconnectAccountEyebrow,
        headline: l10n.desktopDisconnectHeadline(name),
        lines: [l10n.desktopDisconnectAccountLine1(name), l10n.desktopDisconnectAccountLine2(name, wallet!)],
      ),
    };
    if (caution == null) {
      return DeleteWalletStep(
        wallet: wallet!,
        firstLine: l10n.desktopDisconnectWalletLine1(name, wallet),
        delete: () => ref.read(accountManagerProvider).disconnect(widget.account),
        onCancel: widget.onCancel,
        onDeleted: widget.onDisconnected,
        l10n: l10n,
        backedUpKey: AccountInfoSheet.backedUpKey,
        cancelKey: AccountInfoSheet.disconnectCancelKey,
        deleteKey: AccountInfoSheet.disconnectButtonKey,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caution,
        const SizedBox(height: 22),
        SettingsStepFooter(
          error: _error,
          buttons: [
            SheetButton(
              key: AccountInfoSheet.disconnectCancelKey,
              label: l10n.commonCancel,
              kind: SheetButtonKind.secondary,
              onTap: widget.onCancel,
            ),
            SheetButton(
              key: AccountInfoSheet.disconnectButtonKey,
              label: l10n.accountMenuDisconnect,
              kind: SheetButtonKind.destructive,
              isLoading: _isBusy,
              onTap: _disconnect,
            ),
          ],
        ),
      ],
    );
  }
}

/// A local or a hardware account.
class _AccountInfo extends StatelessWidget {
  const _AccountInfo({
    required this.account,
    required this.accounts,
    required this.wallet,
    required this.focusName,
    required this.onRecoveryPhrase,
    required this.onDisconnect,
    required this.l10n,
  });

  final Account account;

  /// All the accounts, for what [account] allows.
  final List<Account> accounts;

  /// What [account]'s wallet is called.
  final String wallet;

  /// Whether the name field takes the focus as the sheet opens.
  final bool focusName;
  final VoidCallback onRecoveryPhrase;
  final VoidCallback onDisconnect;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final plan = disconnectPlanOf(account, accounts);
    final hasPhrase = account.accountType == AccountType.local;

    final walletRows = [
      if (hasPhrase)
        SettingsRow.action(
          key: AccountInfoSheet.recoveryPhraseRowKey,
          title: l10n.settingsWalletRecoveryPhrase,
          subtitle: l10n.desktopAccountInfoPhraseSubtitle(wallet),
          onPressed: onRecoveryPhrase,
        ),
      if (plan != null)
        SettingsRow.action(
          key: AccountInfoSheet.disconnectRowKey,
          title: switch (plan) {
            DisconnectHardware() => l10n.desktopAccountInfoDisconnectHardware,
            DisconnectAccount() || DisconnectWallet() => l10n.desktopAccountInfoDisconnectAccount,
          },
          subtitle: switch (plan) {
            DisconnectHardware() => l10n.desktopAccountInfoDisconnectHardwareSubtitle(account.name),
            DisconnectAccount() => l10n.desktopAccountInfoDisconnectAccountSubtitle(account.name, wallet),
            DisconnectWallet() => l10n.desktopAccountInfoDisconnectWalletSubtitle(account.name, wallet),
          },
          isDestructive: true,
          onPressed: onDisconnect,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: l10n.desktopAccountInfoAccount,
          rows: [
            _NameRow(account: account, autofocus: focusName, l10n: l10n),
            _AddressRow(address: account.accountId, l10n: l10n),
          ],
        ),
        if (walletRows.isNotEmpty) ...[const SizedBox(height: 22), SettingsGroup(label: wallet, rows: walletRows)],
      ],
    );
  }
}

class _MultisigInfo extends StatelessWidget {
  const _MultisigInfo({
    required this.multisig,
    required this.accounts,
    required this.focusName,
    required this.onDisconnect,
    required this.l10n,
  });

  final MultisigAccount multisig;

  /// This wallet's own accounts, to name the signers that are among them.
  final List<Account> accounts;

  /// Whether the name field takes the focus as the sheet opens.
  final bool focusName;
  final VoidCallback onDisconnect;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ownAccounts = accounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: l10n.desktopAccountInfoMultisig,
          rows: [
            _NameRow(account: multisig, autofocus: focusName, l10n: l10n),
            _AddressRow(address: multisig.accountId, l10n: l10n),
            _ValueRow(
              title: l10n.desktopAccountInfoThreshold,
              subtitle: l10n.desktopAccountInfoThresholdSubtitle,
              value: l10n.multisigThresholdOf(multisig.threshold, multisig.signers.length),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          label: l10n.desktopAccountInfoSigners,
          rows: [
            for (final signer in orderedSignersOf(multisig))
              _SignerRow(
                key: AccountInfoSheet.signerKey(signer),
                address: signer,
                own: ownAccounts.where((a) => a.accountId == signer).firstOrNull,
                isCreator: signer == multisig.creator,
                isYou: signer == multisig.myMemberAccountId,
                l10n: l10n,
              ),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          label: l10n.desktopAccountInfoThisDevice,
          rows: [
            SettingsRow.action(
              key: AccountInfoSheet.disconnectRowKey,
              title: l10n.desktopAccountInfoDisconnectMultisig,
              subtitle: l10n.desktopAccountInfoDisconnectMultisigSubtitle(multisig.name),
              isDestructive: true,
              onPressed: onDisconnect,
            ),
          ],
        ),
      ],
    );
  }
}

/// The encrypted account: only its inner hash, which a miner is given so
/// block rewards land in it.
class _EncryptedInfo extends ConsumerStatefulWidget {
  const _EncryptedInfo({required this.account, required this.l10n});

  final Account account;
  final AppLocalizations l10n;

  @override
  ConsumerState<_EncryptedInfo> createState() => _EncryptedInfoState();
}

class _EncryptedInfoState extends ConsumerState<_EncryptedInfo> {
  late final Future<String> _innerHash = ref
      .read(encryptedAccountServiceProvider(widget.account.walletIndex))
      .receiveKeyPair()
      .then((keyPair) => keyPair.rewardsPreimageHex);

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return SettingsGroup(
      label: l10n.desktopAccountInfoMiningRewards,
      rows: [
        FutureBuilder<String>(
          future: _innerHash,
          builder: (context, snapshot) {
            final hash = snapshot.data;
            final value = switch (snapshot) {
              AsyncSnapshot(:final data?) => Text(data, style: text.dataAddress.copyWith(color: colors.textContent)),
              AsyncSnapshot(:final error?) => Text(
                l10n.innerHashLoadError,
                style: text.body.copyWith(color: colors.semanticEmber),
                semanticsLabel: '${l10n.innerHashLoadError}: $error',
              ),
              _ => Text(l10n.commonLoading, style: text.body.copyWith(color: colors.textMuted)),
            };
            // The actions sit on the title's line, so the hash has the
            // row's whole width.
            return _RowPadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(l10n.desktopAccountInfoInnerHash, style: _titleStyle(context))),
                      ToolbarActionRow(
                        edge: ToolbarActionEdge.trailing,
                        spacing: 0,
                        children: [
                          if (_canShare)
                            _ShareAction(actionKey: AccountInfoSheet.shareInnerHashKey, text: hash, l10n: l10n),
                          CopyAction(
                            actionKey: AccountInfoSheet.copyInnerHashKey,
                            text: hash,
                            copyLabel: l10n.receiveCopy,
                            copiedLabel: l10n.desktopCopied,
                          ),
                        ],
                      ),
                    ],
                  ),
                  value,
                  Text(l10n.desktopAccountInfoInnerHashCaption, style: text.body.copyWith(color: colors.textMuted)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The name, typed over in place. Return, or leaving the field, keeps what
/// was typed, trimmed; Escape puts the name back. A blank name, or a write
/// that fails, says why under the title.
class _NameRow extends ConsumerStatefulWidget {
  const _NameRow({required this.account, required this.autofocus, required this.l10n});

  final BaseAccount account;

  /// Takes the focus, with the name selected to be typed over.
  final bool autofocus;
  final AppLocalizations l10n;

  @override
  ConsumerState<_NameRow> createState() => _NameRowState();
}

class _NameRowState extends ConsumerState<_NameRow> {
  /// Why the typed name was not kept, if it was not.
  String? _error;

  // Held for [_keep], which can run once the sheet has closed.
  late final AccountManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(accountManagerProvider);
  }

  /// Keeps [entered] as the account's name, and answers what the field
  /// shows after: the name kept, or the old one when a blank or unchanged
  /// one was not written. A write that fails leaves what was typed.
  Future<String?> _keep(String entered) async {
    final l10n = widget.l10n;
    final account = widget.account;
    if (!_manager.isMounted) return null;
    try {
      final edit = await _manager.rename(account, entered);
      if (!mounted) return null;
      setState(() => _error = edit is NameBlank ? l10n.editAccountNameEmpty : null);
      return switch (edit) {
        NameBlank() || NameUnchanged() => account.name,
        NameChanged(:final name) => name,
      };
    } catch (e) {
      quantusPrint('Renaming ${account.accountId} failed: $e');
      if (mounted) setState(() => _error = l10n.editAccountRenameFailed);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final error = _error;

    return _RowPadding(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(l10n.desktopAccountInfoName, style: _titleStyle(context)),
                Text(
                  error ?? l10n.desktopAccountInfoNameSubtitle,
                  style: text.body.copyWith(color: error == null ? colors.textMuted : colors.semanticEmber),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 260,
            child: InlineNameField(
              key: AccountInfoSheet.nameFieldKey,
              name: widget.account.name,
              autofocus: widget.autofocus,
              onKeep: _keep,
              onCancel: () => setState(() => _error = null),
            ),
          ),
        ],
      ),
    );
  }
}

/// An address over its checkphrase: Share (where the system has a share
/// picker) and Copy level with the address, Copy level with the checkphrase
/// once it is known.
class _AddressRow extends ConsumerStatefulWidget {
  const _AddressRow({required this.address, required this.l10n});

  final String address;
  final AppLocalizations l10n;

  @override
  ConsumerState<_AddressRow> createState() => _AddressRowState();
}

class _AddressRowState extends ConsumerState<_AddressRow> {
  String? _checkphrase;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return _RowPadding(
      child: DesktopAddressCheckphrase(
        address: widget.address,
        onCheckphrase: (phrase) {
          if (mounted) setState(() => _checkphrase = phrase);
        },
        addressActions: [
          if (_canShare) _ShareAction(actionKey: AccountInfoSheet.shareAddressKey, text: widget.address, l10n: l10n),
          CopyAction(
            actionKey: AccountInfoSheet.copyAddressKey,
            text: widget.address,
            copyLabel: l10n.receiveCopy,
            copiedLabel: l10n.desktopCopied,
          ),
        ],
        checkphraseActions: [
          CopyAction(
            actionKey: AccountInfoSheet.copyCheckphraseKey,
            text: _checkphrase,
            copyLabel: l10n.receiveCopy,
            copiedLabel: l10n.desktopCopied,
          ),
        ],
      ),
    );
  }
}

/// Whether the system has a share picker: macOS only, as Receive has it.
bool get _canShare => defaultTargetPlatform == TargetPlatform.macOS;

/// Share, offering [text] to the system's share picker beside it; dimmed
/// while there is no [text] yet.
class _ShareAction extends ConsumerWidget {
  const _ShareAction({required this.actionKey, required this.text, required this.l10n});

  final Key actionKey;
  final String? text;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = this.text;
    return Builder(
      builder: (button) => ToolbarAction.symbol(
        key: actionKey,
        symbol: CupertinoIcons.square_arrow_up,
        label: l10n.componentShare,
        onPressed: text == null
            ? null
            : () => unawaited(ref.read(shareTextProvider)(text, origin: button.sharePositionRect())),
      ),
    );
  }
}

/// A title and its line, with a value at the end.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.title, required this.subtitle, required this.value});

  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return _RowPadding(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: _titleStyle(context)),
                Text(subtitle, style: text.body.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(value, style: text.body.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}

/// A signer: one of this wallet's own accounts by its badge and name, then
/// the address over its checkphrase, with Creator and You marked.
class _SignerRow extends StatelessWidget {
  const _SignerRow({
    super.key,
    required this.address,
    required this.own,
    required this.isCreator,
    required this.isYou,
    required this.l10n,
  });

  final String address;
  final Account? own;
  final bool isCreator;
  final bool isYou;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final own = this.own;
    return _RowPadding(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                if (own != null) AccountLabel(account: own),
                DesktopAddressCheckphrase(address: address),
              ],
            ),
          ),
          if (isCreator) ...[const SizedBox(width: 8), QuantusBadge(label: l10n.desktopAccountInfoCreator)],
          if (isYou) ...[const SizedBox(width: 8), QuantusBadge(label: l10n.desktopAccountInfoYou)],
        ],
      ),
    );
  }
}

/// The insets of a row the Info sheet draws itself in a [SettingsGroup],
/// the same as [SettingsRow]'s.
class _RowPadding extends StatelessWidget {
  const _RowPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: child);
}

TextStyle _titleStyle(BuildContext context) =>
    context.themeTextV3.bodyEmphasis.copyWith(color: context.colorsV3.textContent);
