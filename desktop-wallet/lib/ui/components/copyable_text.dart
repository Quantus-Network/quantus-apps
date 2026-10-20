import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Selectable value with a copy button that confirms in a toast.
class CopyableText extends StatelessWidget {
  final String value;
  final String copiedMessage;
  final TextStyle? style;
  final String? display;

  const CopyableText({super.key, required this.value, required this.copiedMessage, this.style, this.display});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SelectableText(display ?? value, style: style ?? text.dataAddress.copyWith(color: colors.textContent)),
        ),
        const SizedBox(width: 4),
        QuantusIconButton.ghost(
          icon: Icons.copy_rounded,
          size: IconButtonSize.small,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) await context.showCopyToaster(message: copiedMessage);
          },
        ),
      ],
    );
  }
}
