import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/receive_address.dart';

/// What the Receive sheet holds for the active account: its QR code, the
/// address it is paid at and that address's checkphrase, each with a Copy
/// beside it. The encrypted account is paid at its next unused deposit
/// address, and says why that address changes.
class ReceiveSheet extends ConsumerStatefulWidget {
  const ReceiveSheet({super.key});

  static const copyAddressKey = Key('receive-copy-address');
  static const copyCheckphraseKey = Key('receive-copy-checkphrase');
  static const shareKey = Key('receive-share');
  static const encryptedNoticeKey = Key('receive-encrypted-notice');

  @override
  ConsumerState<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends ConsumerState<ReceiveSheet> {
  static const double _qrSize = 176;

  /// The sheet opens on the active account and stays on it while it is open.
  late final BaseAccount _account = ref.read(activeAccountProvider).value!.account;

  /// Worked out once per opening: the encrypted account's next deposit
  /// address can change between openings.
  late final Future<String> _address = receiveAddress(ref.read, _account);

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;

    return FutureBuilder<String>(
      future: _address,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(:final data?) => _Details(account: _account, address: data, l10n: l10n),
        AsyncSnapshot(:final error?) => Text(
          l10n.receiveErrorLoadingAccount('$error'),
          style: context.themeTextV3.body.copyWith(color: colors.semanticEmber),
        ),
        _ => const SizedBox(
          height: _qrSize,
          child: Center(child: Loader()),
        ),
      },
    );
  }
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.account, required this.address, required this.l10n});

  final BaseAccount account;
  final String address;
  final AppLocalizations l10n;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  /// The address's checkphrase, once it has been looked up.
  String? _checkphrase;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final isEncrypted = isEncryptedAccount(widget.account);
    final labelStyle = text.dataAddress.copyWith(height: 1, letterSpacing: 1.4, color: colors.textMuted2);
    final valueStyle = text.dataAddressLarge.copyWith(height: 1.6, letterSpacing: 0.4);
    // Only macOS has a share picker to hand the address to.
    final canShare = defaultTargetPlatform == TargetPlatform.macOS;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: _ReceiveSheetState._qrSize,
          child: FittedBox(child: QuantusQr(accountId: widget.address)),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Value(
                label: CapsText(
                  isEncrypted ? l10n.desktopReceiveDepositAddressLabel : l10n.receiveYourAddressLabel,
                  style: labelStyle,
                ),
                actions: [
                  if (canShare)
                    Builder(
                      builder: (button) => ToolbarAction.symbol(
                        key: ReceiveSheet.shareKey,
                        symbol: CupertinoIcons.square_arrow_up,
                        label: l10n.componentShare,
                        onPressed: () =>
                            ref.read(shareTextProvider)(widget.address, origin: button.sharePositionRect()),
                      ),
                    ),
                  CopyAction(
                    actionKey: ReceiveSheet.copyAddressKey,
                    text: widget.address,
                    copyLabel: l10n.receiveCopy,
                    copiedLabel: l10n.desktopCopied,
                  ),
                ],
                value: Text(widget.address, style: valueStyle.copyWith(color: colors.textWhite)),
              ),
              const SizedBox(height: 18),
              const MenuDivider(),
              const SizedBox(height: 18),
              _Value(
                label: CapsText(l10n.componentCheckphraseLabel, style: labelStyle),
                actions: [
                  CopyAction(
                    actionKey: ReceiveSheet.copyCheckphraseKey,
                    text: _checkphrase,
                    copyLabel: l10n.receiveCopy,
                    copiedLabel: l10n.desktopCopied,
                  ),
                ],
                value: CheckphraseText(
                  widget.address,
                  style: valueStyle.copyWith(color: colors.semanticLilac),
                  onResolved: (phrase) {
                    if (mounted) setState(() => _checkphrase = phrase);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.receiveCheckphraseFootnote, style: text.body.copyWith(color: colors.textMuted)),
              if (isEncrypted) ...[
                const SizedBox(height: 16),
                _EncryptedNotice(text: l10n.desktopReceiveEncryptedNotice),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled value with its actions at the end of the label's line.
class _Value extends StatelessWidget {
  const _Value({required this.label, required this.actions, required this.value});

  final Widget label;
  final List<Widget> actions;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: label),
            ...actions,
          ],
        ),
        const SizedBox(height: 8),
        value,
      ],
    );
  }
}

/// Why the encrypted account's deposit address changes.
class _EncryptedNotice extends StatelessWidget {
  const _EncryptedNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Container(
      key: ReceiveSheet.encryptedNoticeKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accentFlare.useOpacity(0.08),
        borderRadius: context.radiusV3.smBorder,
        border: Border.all(color: colors.accentFlare.useOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(CupertinoIcons.lock_fill, size: 13, color: colors.accentFlare),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: context.themeTextV3.body.copyWith(color: colors.textContent)),
          ),
        ],
      ),
    );
  }
}
