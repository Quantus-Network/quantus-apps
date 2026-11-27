import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/activity/inspector_parts.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/explorer_url.dart';

/// An encrypted send's proof batches, as the phone's Wormhole details lists
/// them, under a heading that opens and closes them, closed at first. Each
/// batch: when, what it sent, its change and fee, its hash, the inputs it
/// spent by amount and whole nullifier, and its page. [feeLabel] names a
/// batch's fee as the send's own is named.
class WormholeBatches extends ConsumerStatefulWidget {
  const WormholeBatches({super.key, required this.send, required this.feeLabel});

  final WormholeTransferEvent send;
  final String feeLabel;

  static const headingKey = Key('wormhole-batches-heading');

  static Key batchKey(String extrinsicId) => ValueKey('wormhole-batch-$extrinsicId');

  @override
  ConsumerState<WormholeBatches> createState() => _WormholeBatchesState();
}

class _WormholeBatchesState extends ConsumerState<WormholeBatches> {
  bool _isOpen = false;

  void _toggle() => setState(() => _isOpen = !_isOpen);

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final batches = widget.send.batches;
    final name = l10n.desktopActivityBatches(batches.length);
    final radius = context.radiusV3.smBorder;

    // Drawn in capitals, which is a look: a screen reader gets the words.
    final heading = Semantics(
      key: WormholeBatches.headingKey,
      label: name,
      button: true,
      expanded: _isOpen,
      onTap: _toggle,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: _toggle,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(name.toUpperCase(), style: inspectorCapsStyle(context).copyWith(letterSpacing: 1.4)),
                ),
                Icon(
                  _isOpen ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                  size: 11,
                  color: colors.textMuted2,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        if (_isOpen)
          for (final (index, batch) in batches.indexed)
            _Batch(
              key: WormholeBatches.batchKey(batch.extrinsicId),
              batch: batch,
              title: l10n.wormholeDetailsBatch(index + 1, batches.length),
              showsSent: !widget.send.recipientUnknown,
              feeLabel: widget.feeLabel,
            ),
      ],
    );
  }
}

/// One proof extrinsic of the send, under its [title].
class _Batch extends ConsumerWidget {
  const _Batch({super.key, required this.batch, required this.title, required this.showsSent, required this.feeLabel});

  final WormholeSendBatch batch;
  final String title;

  /// Whether what it paid the recipient is known.
  final bool showsSent;
  final String feeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatting = ref.watch(numberFormattingServiceProvider);
    String money(BigInt value) => l10n.commonAmountBalance(formatting.formatBalance(value), AppConstants.tokenSymbol);
    final caps = inspectorCapsStyle(context).copyWith(letterSpacing: 1.4);
    final whole = text.dataAddress.copyWith(height: 1.3, letterSpacing: 0.3, color: colors.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        const MenuDivider(),
        const SizedBox(height: 14),
        CapsText(title, style: caps),
        const SizedBox(height: 8),
        Text(
          DatetimeFormattingService.formatTxDateTime(batch.timestamp),
          style: text.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 6),
        if (showsSent) FigureRow(label: l10n.desktopActivityBatchSent, value: money(batch.sentToken)),
        if (batch.changeToken > BigInt.zero)
          FigureRow(label: l10n.desktopActivityBatchChange, value: money(batch.changeToken)),
        if (batch.feeToken > BigInt.zero) FigureRow(label: feeLabel, value: money(batch.feeToken)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: CapsText(l10n.desktopActivityTransaction, style: caps)),
            CopyAction(text: batch.extrinsicId, copyLabel: l10n.receiveCopy, copiedLabel: l10n.desktopCopied),
          ],
        ),
        const SizedBox(height: 6),
        Text(batch.extrinsicId, style: whole),
        const SizedBox(height: 16),
        CapsText(l10n.desktopActivityBatchInputs(batch.inputs.length), style: caps),
        for (final input in batch.inputs) ...[
          const SizedBox(height: 10),
          Text(money(input.amount), style: text.body.copyWith(color: colors.textContent)),
          const SizedBox(height: 2),
          Text(input.nullifierHex, style: whole),
        ],
        const SizedBox(height: 14),
        InspectorPageActions(page: wormholeExplorerUrl(batch.extrinsicId)),
      ],
    );
  }
}
