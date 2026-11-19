import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// An account as every sheet names one: its badge, then its name. A name
/// too long for the room is cut short; the badge stays whole.
class AccountLabel extends StatelessWidget {
  const AccountLabel({super.key, required this.account, this.size = badgeSize, this.style});

  final BaseAccount account;

  /// How large the badge is drawn.
  final double size;

  /// The name's style; a line of the sheet's text when not given.
  final TextStyle? style;

  /// The badge's size beside a line of text.
  static const double badgeSize = 24;

  /// The space between the badge and the name.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    return Row(
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
  }
}
