import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// An address with its checkphrase under it, at desktop size: the whole
/// address, never shortened, and both in the monospaced face. Wherever this
/// app shows an address it shows it this way.
///
/// The order and the checkphrase's lookup are the shared
/// [AddressCheckphrase]'s; this gives it the desktop's look. [isCompact]
/// sets it a size smaller, as a list's rows and a side panel show it.
///
/// [addressActions] and [checkphraseActions] sit at the end of their line,
/// level with it; [onCheckphrase] is told the checkphrase once it is known.
class DesktopAddressCheckphrase extends StatelessWidget {
  const DesktopAddressCheckphrase({
    super.key,
    required this.address,
    this.isCompact = false,
    this.addressActions = const [],
    this.checkphraseActions = const [],
    this.onCheckphrase,
  });

  final String address;
  final bool isCompact;
  final List<Widget> addressActions;
  final List<Widget> checkphraseActions;
  final ValueChanged<String>? onCheckphrase;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final face = isCompact ? context.themeTextV3.dataAddress : context.themeTextV3.dataAddressLarge;
    final style = face.copyWith(height: 1.3, letterSpacing: 0.3);
    final addressStyle = style.copyWith(color: isCompact ? colors.textContent : colors.textWhite);
    final checkphraseStyle = style.copyWith(color: colors.semanticLilac);

    if (addressActions.isEmpty && checkphraseActions.isEmpty && onCheckphrase == null) {
      return AddressCheckphrase(address: address, addressStyle: addressStyle, checkphraseStyle: checkphraseStyle);
    }

    // The same order as [AddressCheckphrase]'s, with each line's actions.
    Widget line(Widget text, List<Widget> actions) => Row(
      children: [
        Expanded(child: text),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 16),
          ToolbarActionRow(edge: ToolbarActionEdge.trailing, spacing: 0, children: actions),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        line(Text(address, style: addressStyle), addressActions),
        const SizedBox(height: 4),
        line(CheckphraseText(address, style: checkphraseStyle, onResolved: onCheckphrase), checkphraseActions),
      ],
    );
  }
}
