import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/utils/recovery_phrase.dart';

/// The field a recovery phrase is typed or pasted into: masked, with how many
/// words it holds and a Paste button under the phrase.
class RecoveryPhraseInput extends ConsumerWidget {
  const RecoveryPhraseInput({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.canPaste,
    required this.height,
  });

  final ObscuringTextEditingController controller;

  /// Called when the phrase changes, typed or pasted.
  final VoidCallback onChanged;

  final bool canPaste;
  final double height;

  /// The count of the words typed so far.
  static const wordCountKey = Key('import-wallet-word-count');

  /// The small monospace capitals of the count, and of labels beside it.
  static TextStyle labelStyle(BuildContext context, Color color) =>
      context.themeTextV3.dataAddress.copyWith(height: 1, letterSpacing: 1.4, color: color);

  /// Puts the clipboard's text in the field, in place of what was there. With
  /// no text on the clipboard there is nothing to paste.
  Future<void> _paste(BuildContext context) async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || !context.mounted) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final count = recoveryPhraseWords(controller.text).length;
    final isWhole = count == 12 || count == 24;

    return QuantusSeedPhraseField(
      controller: controller,
      hint: l10n.importWalletHint,
      height: height,
      onChanged: (_) => onChanged(),
      footer: Row(
        children: [
          CapsText(
            key: wordCountKey,
            l10n.desktopImportWordCount(count),
            style: labelStyle(context, isWhole ? colors.semanticSage : colors.textMuted2),
          ),
          const Spacer(),
          ToolbarAction.symbol(
            symbol: CupertinoIcons.doc_on_clipboard,
            label: l10n.desktopImportPaste,
            onPressed: canPaste ? () => _paste(context) : null,
          ),
        ],
      ),
    );
  }
}
