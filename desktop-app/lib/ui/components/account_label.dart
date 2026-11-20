import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/hover_popover.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// An account as every sheet names one: its badge, then its name. A name
/// too long for the room is cut short; the badge stays whole.
///
/// Where the account is a sender or receiver ([revealsAddress]), the pointer
/// resting on it shows its whole address over its checkphrase, with Copy,
/// and a screen reader hears the address after the name. The Encrypted
/// account has no single address (each payment to it goes to a new one), so
/// it never does.
class AccountLabel extends StatelessWidget {
  const AccountLabel({
    super.key,
    required this.account,
    this.size = badgeSize,
    this.style,
    this.revealsAddress = false,
  });

  final BaseAccount account;

  /// How large the badge is drawn.
  final double size;

  /// The name's style; a line of the sheet's text when not given.
  final TextStyle? style;

  /// Whether the account is named as a sender or receiver, so the pointer
  /// resting on it shows its address.
  final bool revealsAddress;

  /// The badge's size beside a line of text.
  static const double badgeSize = 24;

  /// The space between the badge and the name.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesktopAccountBadge(account: account, size: size),
        const SizedBox(width: gap),
        Flexible(
          child: Text(
            account.name,
            overflow: TextOverflow.ellipsis,
            style: style ?? context.themeTextV3.body.copyWith(color: context.colorsV3.textContent),
          ),
        ),
      ],
    );
    if (!revealsAddress || isEncryptedAccount(account)) return label;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${account.name}, ${account.accountId}',
      child: HoverPopover(
        anchorX: size / 2,
        popover: _AddressPopover(address: account.accountId),
        child: label,
      ),
    );
  }
}

/// An account's whole address over its checkphrase, under its heading, with
/// Copy beside it.
class _AddressPopover extends ConsumerWidget {
  const _AddressPopover({required this.address});

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CapsText(
                l10n.desktopMarksAddress,
                style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted, letterSpacing: 0.8),
              ),
              const SizedBox(width: 24),
              const Spacer(),
              CopyAction(text: address, copyLabel: l10n.receiveCopy, copiedLabel: l10n.desktopCopied),
            ],
          ),
          const SizedBox(height: 8),
          DesktopAddressCheckphrase(address: address, isCompact: true),
        ],
      ),
    );
  }
}
