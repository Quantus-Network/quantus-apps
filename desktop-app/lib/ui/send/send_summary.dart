import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/send/send_review_row.dart';

/// Who a send pays and what it costs, as the review shows it before the send
/// and the receipt after: the recipient's checkphrase over the whole address,
/// then the account it leaves, the send's own figures, and under a line of
/// its own what leaves the account in all.
///
/// The figures are the send's [rows]. The recipient and the amount among
/// them are left out, since they are shown above; the fee and the total get
/// this app's own labels, the total's being [totalLabel].
class SendSummary extends StatelessWidget {
  const SendSummary({
    super.key,
    required this.l10n,
    required this.recipient,
    required this.from,
    required this.rows,
    required this.totalLabel,
  });

  final AppLocalizations l10n;
  final String recipient;

  /// The name of the account the send leaves.
  final String from;
  final List<SendReviewRow> rows;
  final String totalLabel;

  /// What stands beside a row's label.
  static String _value(SendReviewRow row) => switch (row) {
    SendReviewText(:final value) => value,
    // Rows of a multisig proposal, which this app does not make yet.
    SendReviewAddress() || SendReviewExpiry() => throw UnsupportedError('The desktop app does not draw $row yet.'),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final totals = rows.where((row) => row.kind == SendReviewRowKind.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CapsText(l10n.sendTxSubmittedToLabel, style: context.sendCaps()),
        const SizedBox(height: 10),
        CheckphraseText(recipient, style: context.sendMono(colors.semanticLilac)),
        const SizedBox(height: 4),
        Text(recipient, style: context.sendMono(colors.textWhite)),
        const SizedBox(height: 20),
        const MenuDivider(),
        const SizedBox(height: 4),
        _FigureRow(label: l10n.activityTxFrom, value: from),
        for (final row in rows)
          switch (row.kind) {
            SendReviewRowKind.recipient ||
            SendReviewRowKind.amount ||
            SendReviewRowKind.total => const SizedBox.shrink(),
            SendReviewRowKind.fee => _FigureRow(label: l10n.swapReviewNetworkFee, value: _value(row)),
            SendReviewRowKind.detail => _FigureRow(label: row.label, value: _value(row)),
          },
        if (totals.isNotEmpty) ...[
          const MenuDivider(),
          const SizedBox(height: 4),
          for (final row in totals) _FigureRow(label: totalLabel, value: _value(row), isStrong: true),
        ],
      ],
    );
  }
}

/// A label and its figure at the two ends of a line.
class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.label, required this.value, this.isStrong = false});

  final String label;
  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(label, style: context.sendBody(color: isStrong ? colors.textContent : null)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: (isStrong ? text.bodyEmphasis : text.body).copyWith(
                color: colors.textContent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
