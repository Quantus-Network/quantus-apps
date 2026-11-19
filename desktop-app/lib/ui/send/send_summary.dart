import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/send/send_review_row.dart';

/// Who a send pays and what it costs, as the review shows it before the send
/// and the receipt after: the recipient's whole address over its checkphrase,
/// then the account it leaves and the send's own lines. What is paid in all
/// stands under them, apart ([SendTotal]).
///
/// The lines are the send's [rows]. The recipient and the amount among them
/// are left out, since they are shown above, and the total, which is
/// [SendTotal]'s; the fee gets this app's own label, [feeLabel].
///
/// A multisig's proposal is signed and paid for by a member's account, its
/// [signer], not by the multisig it leaves. Its review names that account,
/// how many approvals it needs and when it expires, then, apart, what
/// proposing costs. Its receipt, which knows how many [approvals] it has,
/// shows those in place of how many are needed, and leaves the costs to the
/// total.
class SendSummary extends StatelessWidget {
  const SendSummary({
    super.key,
    required this.l10n,
    required this.recipient,
    required this.from,
    required this.rows,
    required this.feeLabel,
    this.signer,
    this.approvals,
  });

  final AppLocalizations l10n;
  final String recipient;

  /// The account the send leaves.
  final BaseAccount from;
  final List<SendReviewRow> rows;
  final String feeLabel;

  /// The account that signs a proposal and pays what it costs.
  final Account? signer;

  /// How many approvals a submitted proposal has.
  final int? approvals;

  /// A submitted proposal's receipt.
  bool get _isProposalReceipt => signer != null && approvals != null;

  /// What a proposal's lines need of its signer.
  Account get _signer => signer ?? (throw StateError('A proposal\'s rows were given no account that signs it.'));

  static bool _isCost(SendReviewRow row) =>
      row.kind == SendReviewRowKind.fee ||
      row.kind == SendReviewRowKind.deposit ||
      row.kind == SendReviewRowKind.charge;

  /// The figure of a line that is one.
  static String _figure(SendReviewRow row) => switch (row) {
    SendReviewText(:final value) => value,
    SendReviewAddress() ||
    SendReviewExpiry() ||
    SendReviewThreshold() => throw UnsupportedError('The desktop app draws no figure for $row.'),
  };

  /// The line of [row], or null for a row this summary leaves out.
  Widget? _line(BuildContext context, SendReviewRow row) {
    final colors = context.colorsV3;

    switch (row) {
      case SendReviewThreshold(:final threshold, :final signers):
        final approved = approvals;
        return _SummaryRow(
          label: Text(
            approved == null ? l10n.desktopProposeApprovalsNeeded : l10n.desktopProposeApprovals,
            style: context.sendBody(),
          ),
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ApprovalMarks(approved: approved ?? 0, needed: threshold),
              const SizedBox(width: 9),
              _FigureText(
                approved == null
                    ? l10n.desktopProposeCountOf(threshold, signers)
                    : l10n.desktopProposeCountOf(approved, threshold),
              ),
            ],
          ),
        );
      case SendReviewExpiry(:final expiry):
        final date = expiry.estimatedDateTime;
        return _SummaryRow(
          label: Text(l10n.desktopProposeExpires, style: context.sendBody()),
          // The date it stands for leads; until it is known the block does.
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (date != null) ...[Flexible(child: _FigureText(date)), const SizedBox(width: 10)],
              Text(
                expiry.blockLabel,
                style: context.sendBody(color: date == null ? colors.textContent : colors.textMuted2),
              ),
            ],
          ),
        );
      case SendReviewAddress() || SendReviewText():
        break;
    }

    switch (row.kind) {
      case SendReviewRowKind.recipient || SendReviewRowKind.amount || SendReviewRowKind.total:
        return null;
      case SendReviewRowKind.signer:
        if (_isProposalReceipt) return null;
        return _SummaryRow(
          label: Text(l10n.desktopProposeProposedBy, style: context.sendBody()),
          value: AccountLabel(account: _signer),
        );
      case SendReviewRowKind.fee:
        if (_isProposalReceipt) return null;
        return _FigureRow(label: feeLabel, value: _figure(row));
      case SendReviewRowKind.deposit:
        if (_isProposalReceipt) return null;
        return _SummaryRow(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.desktopProposeDeposit, style: context.sendBody()),
              const SizedBox(width: 10),
              QuantusBadge(label: l10n.multisigProposeDepositRefundableNote, tone: BadgeTone.sage),
            ],
          ),
          value: _FigureText(_figure(row)),
        );
      case SendReviewRowKind.charge:
        if (_isProposalReceipt) return null;
        return _FigureRow(label: l10n.desktopProposeFee, value: _figure(row));
      case SendReviewRowKind.detail:
        return _FigureRow(label: row.label, value: _figure(row));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A proposal's costs are another account's, so they stand apart from
    // what the proposal is.
    final firstCost = signer == null ? null : rows.where(_isCost).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CapsText(l10n.sendTxSubmittedToLabel, style: context.sendCaps()),
        const SizedBox(height: 10),
        DesktopAddressCheckphrase(address: recipient),
        const SizedBox(height: 20),
        const MenuDivider(),
        const SizedBox(height: 4),
        _SummaryRow(
          label: Text(l10n.activityTxFrom, style: context.sendBody()),
          value: AccountLabel(account: from),
        ),
        for (final row in rows)
          if (_line(context, row) case final line?) ...[
            if (identical(row, firstCost)) ...[const MenuDivider(), const SizedBox(height: 4)],
            line,
          ],
      ],
    );
  }
}

/// What a send's [rows] say is paid in all, under a line of its own: the
/// figure after [label], or after the name of the [signer] and [label] where
/// another account than the one the send leaves pays it, a proposal's member.
class SendTotal extends StatelessWidget {
  const SendTotal({super.key, required this.rows, required this.label, this.signer});

  final List<SendReviewRow> rows;
  final String label;
  final Account? signer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final signer = this.signer;
    final totals = rows.where((row) => row.kind == SendReviewRowKind.total);
    if (totals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MenuDivider(),
        const SizedBox(height: 4),
        for (final row in totals)
          if (signer == null)
            _FigureRow(label: label, value: SendSummary._figure(row), isStrong: true)
          else
            // The figure is whole whatever the account is called: the name
            // takes what is left of the line, and is cut short there.
            Padding(
              padding: _SummaryRow.padding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: AccountLabel(
                            account: signer,
                            style: text.bodyEmphasis.copyWith(color: colors.textContent),
                          ),
                        ),
                        // A word's space after the name.
                        const SizedBox(width: 4),
                        Text(label, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
                      ],
                    ),
                  ),
                  const SizedBox(width: _SummaryRow.gap),
                  _FigureText(SendSummary._figure(row), isStrong: true),
                ],
              ),
            ),
      ],
    );
  }
}

/// A label and what stands for it, at the two ends of a line.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final Widget label;
  final Widget value;

  static const padding = EdgeInsets.symmetric(vertical: 9);

  /// The least space between the label and what stands for it.
  static const double gap = 16;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          label,
          const SizedBox(width: gap),
          Expanded(
            child: Align(alignment: AlignmentDirectional.centerEnd, child: value),
          ),
        ],
      ),
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
    return _SummaryRow(
      label: Text(label, style: context.sendBody(color: isStrong ? context.colorsV3.textContent : null)),
      value: _FigureText(value, isStrong: isStrong),
    );
  }
}

/// A figure, or other short text, at the end of its line.
class _FigureText extends StatelessWidget {
  const _FigureText(this.value, {this.isStrong = false});

  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;

    return Text(
      value,
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
      style: (isStrong ? text.bodyEmphasis : text.body).copyWith(
        color: context.colorsV3.textContent,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
