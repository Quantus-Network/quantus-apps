import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A note about an account, shown where the account is ("Address copied"):
/// sage with a check, or ember when something failed. A screen reader
/// announces it as it appears.
class AccountNoteText extends StatelessWidget {
  const AccountNoteText({super.key, required this.note, this.style});

  final AccountNote note;

  /// The text's style, coloured by the note; the caption style when null.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final color = note.isError ? colors.semanticEmber : colors.semanticSage;
    final style = (this.style ?? context.themeTextV3.caption).copyWith(color: color);

    return Semantics(
      liveRegion: true,
      label: note.message,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            note.isError ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.checkmark_alt,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(note.message, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
