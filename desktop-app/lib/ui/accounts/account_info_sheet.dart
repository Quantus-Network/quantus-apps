import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
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
  static const recoveryPhraseRowKey = Key('account-info-recovery-phrase');
  static const disconnectRowKey = Key('account-info-disconnect');

  static Key signerKey(String accountId) => ValueKey('account-info-signer-$accountId');

  @override
  ConsumerState<AccountInfoSheet> createState() => _AccountInfoSheetState();
}

class _AccountInfoSheetState extends ConsumerState<AccountInfoSheet> {
  /// Read once: the sheet stays on the account it opened for.
  late final AccountInfoTarget _target =
      ref.read(accountInfoTargetProvider) ?? (throw StateError('The Info sheet opened without an account'));

  bool _isClosing = false;

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
    final l10n = ref.watch(l10nProvider);
    final id = _target.accountId;
    final accounts = ref.watch(accountsProvider).value;
    final multisigs = ref.watch(multisigAccountsProvider).value;
    if (accounts != null && multisigs != null) {
      final account =
          accounts.firstWhereOrNull((a) => a.accountId == id) ?? multisigs.firstWhereOrNull((m) => m.accountId == id);
      if (account == null) {
        _close();
      } else {
        _account = account;
        _accounts = accounts;
        if (account is Account) _wallet = ref.watch(walletLabelProvider(account.walletIndex));
      }
    }
    final account = _account;
    if (account == null) return const SizedBox.shrink();

    final body = switch (account) {
      MultisigAccount() => _MultisigInfo(multisig: account, accounts: _accounts, l10n: l10n),
      Account(accountType: AccountType.encrypted) => _EncryptedInfo(account: account, l10n: l10n),
      Account() => _AccountInfo(account: account, accounts: _accounts, wallet: _wallet!, l10n: l10n),
      _ => throw StateError('${account.accountId} has no Info sheet'),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellSheetHeader(
          title: account is MultisigAccount ? l10n.desktopMultisigInfoTitle : l10n.desktopAccountInfoTitle,
          account: account,
        ),
        const SizedBox(height: 18),
        // Longer than the window, it scrolls within the sheet.
        Flexible(child: SingleChildScrollView(child: body)),
      ],
    );
  }
}

/// A local or a hardware account.
class _AccountInfo extends StatelessWidget {
  const _AccountInfo({required this.account, required this.accounts, required this.wallet, required this.l10n});

  final Account account;

  /// All the accounts, for what [account] allows.
  final List<Account> accounts;

  /// What [account]'s wallet is called.
  final String wallet;
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
          onPressed: null,
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
          onPressed: null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: l10n.desktopAccountInfoAccount,
          rows: [
            _NameRow(account: account, l10n: l10n),
            _AddressRow(address: account.accountId, l10n: l10n),
          ],
        ),
        if (walletRows.isNotEmpty) ...[const SizedBox(height: 22), SettingsGroup(label: wallet, rows: walletRows)],
      ],
    );
  }
}

class _MultisigInfo extends StatelessWidget {
  const _MultisigInfo({required this.multisig, required this.accounts, required this.l10n});

  final MultisigAccount multisig;

  /// This wallet's own accounts, to name the signers that are among them.
  final List<Account> accounts;
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
            _NameRow(account: multisig, l10n: l10n),
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
                own: ownAccounts.firstWhereOrNull((a) => a.accountId == signer),
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
              onPressed: null,
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
            return _RowPadding(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Text(l10n.desktopAccountInfoInnerHash, style: _titleStyle(context)),
                        value,
                        Text(
                          l10n.desktopAccountInfoInnerHashCaption,
                          style: text.body.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  CopyAction(
                    actionKey: AccountInfoSheet.copyInnerHashKey,
                    text: hash,
                    copyLabel: l10n.receiveCopy,
                    copiedLabel: l10n.desktopCopied,
                  ),
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
  const _NameRow({required this.account, required this.l10n});

  final BaseAccount account;
  final AppLocalizations l10n;

  @override
  ConsumerState<_NameRow> createState() => _NameRowState();
}

class _NameRowState extends ConsumerState<_NameRow> {
  late final _controller = TextEditingController(text: widget.account.name);
  final _focus = FocusNode();

  /// Why the typed name was not kept, if it was not.
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_NameRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Renamed elsewhere while not being typed in.
    if (!_focus.hasFocus && widget.account.name != oldWidget.account.name) _controller.text = widget.account.name;
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _keep();
  }

  Future<void> _keep() async {
    final l10n = widget.l10n;
    final account = widget.account;
    try {
      final edit = await ref.read(accountManagerProvider).rename(account, _controller.text);
      if (!mounted) return;
      setState(() {
        switch (edit) {
          case NameBlank():
            _error = l10n.editAccountNameEmpty;
            _controller.text = account.name;
          case NameUnchanged():
            _error = null;
            _controller.text = account.name;
          case NameChanged(:final name):
            _error = null;
            _controller.text = name;
        }
      });
    } catch (e) {
      quantusPrint('Renaming ${account.accountId} failed: $e');
      if (mounted) setState(() => _error = l10n.editAccountRenameFailed);
    }
  }

  /// Escape while typing puts the name back, and leaves the sheet open.
  void _putBack() {
    _controller.text = widget.account.name;
    setState(() => _error = null);
    _focus.unfocus();
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
            child: Actions(
              actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => _putBack())},
              child: QuantusTextField(
                key: AccountInfoSheet.nameFieldKey,
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _focus.unfocus(),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: text.body.copyWith(color: colors.textContent),
                fillColor: colors.bgVoid,
                borderRadius: context.radiusV3.smBorder,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An address over its checkphrase, with Copy.
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.l10n});

  final String address;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _RowPadding(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: DesktopAddressCheckphrase(address: address)),
          const SizedBox(width: 16),
          CopyAction(
            actionKey: AccountInfoSheet.copyAddressKey,
            text: address,
            copyLabel: l10n.receiveCopy,
            copiedLabel: l10n.desktopCopied,
          ),
        ],
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
