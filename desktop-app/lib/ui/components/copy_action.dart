import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';

/// A Copy beside a value: puts [text] on the clipboard, then says
/// [copiedLabel] with a check for a moment, so the copy is seen to have
/// happened. Unavailable while [text] is null.
class CopyAction extends StatefulWidget {
  const CopyAction({super.key, required this.text, required this.copyLabel, required this.copiedLabel, this.actionKey});

  final String? text;
  final String copyLabel;
  final String copiedLabel;

  /// Given to the action itself, so it can be found.
  final Key? actionKey;

  /// How long [copiedLabel] shows.
  static const copiedFor = Duration(seconds: 2);

  @override
  State<CopyAction> createState() => _CopyActionState();
}

class _CopyActionState extends State<CopyAction> {
  Timer? _copied;

  @override
  void dispose() {
    _copied?.cancel();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _copied?.cancel();
    setState(() => _copied = Timer(CopyAction.copiedFor, () => setState(() => _copied = null)));
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isCopied = _copied != null;

    return ToolbarAction.symbol(
      key: widget.actionKey,
      symbol: isCopied ? CupertinoIcons.checkmark_alt : CupertinoIcons.doc_on_doc,
      label: isCopied ? widget.copiedLabel : widget.copyLabel,
      onPressed: text == null ? null : () => _copy(text),
    );
  }
}
