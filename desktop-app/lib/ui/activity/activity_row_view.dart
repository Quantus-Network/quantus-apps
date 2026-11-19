import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// How much of a row there is room for.
enum ActivityRowForm {
  /// One line: what and when, then who, whole, then the amount.
  wide,

  /// What, when and the amount on top, who under them.
  tight,

  /// What, when and the amount; who is left to the panel it opens.
  brief;

  /// The least width the wide rows fit, a whole address with them.
  static const double wideFrom = 700;

  /// The least width the tight rows fit, a whole address under them.
  static const double tightFrom = 440;

  /// The form that fits [width].
  static ActivityRowForm of(double width) => width >= wideFrom
      ? ActivityRowForm.wide
      : width >= tightFrom
      ? ActivityRowForm.tight
      : ActivityRowForm.brief;
}

/// One row of an activity list: its picture, what happened and when, who was
/// on the other side, and the amount, in the [form] there is room for. What
/// it says is wallet_core's [row]; the amount comes formatted, unsigned
/// ([amountText]).
///
/// It has a soft backing under the pointer and a stronger one when it is
/// open ([isSelected]), quieter while the keys are in another panel
/// ([hasFocus] false).
class ActivityRowView extends StatefulWidget {
  const ActivityRowView({
    super.key,
    required this.id,
    required this.row,
    required this.amountText,
    required this.form,
    required this.l10n,
    this.ownCounterparty,
    this.isSelected = false,
    this.hasFocus = true,
    this.onTap,
  });

  /// The transaction's id, which the lists know it by.
  final String id;

  final ActivityRow row;
  final String amountText;
  final ActivityRowForm form;
  final AppLocalizations l10n;

  /// The wallet's own account on the other side, shown by its badge and
  /// name instead of its address.
  final BaseAccount? ownCounterparty;

  final bool isSelected;
  final bool hasFocus;
  final VoidCallback? onTap;

  /// The space the label and its time take on a wide row.
  static const double _whatWidth = 150;

  /// The space before who on a wide row, and on a tight one.
  static const double _prefixWidth = 58;
  static const double _tightPrefixWidth = 52;

  @override
  State<ActivityRowView> createState() => _ActivityRowViewState();
}

class _ActivityRowViewState extends State<ActivityRowView> {
  bool _isHovered = false;

  ActivityRow get _row => widget.row;

  /// What the row's words and picture are drawn in: glacier while money
  /// leaves, sage while it arrives, plain once settled.
  Color _accent(AppColorsV3 colors) => switch (_row.highlight) {
    ActivityHighlight.none => colors.textContent,
    ActivityHighlight.arriving => colors.semanticSage,
    ActivityHighlight.leaving => colors.semanticGlacier,
  };

  Widget _icon(AppColorsV3 colors) {
    final accent = _accent(colors);
    final isUnderWay = _row.highlight != ActivityHighlight.none;
    final glyph = switch (_row.icon) {
      ActivityIcon.direction => QuantusIcon(
        _row.isSend ? QuantusIcons.actionSend : QuantusIcons.actionReceive,
        size: 14,
        color: accent,
      ),
      ActivityIcon.proposal => Icon(Icons.how_to_vote_outlined, size: 14, color: accent),
      ActivityIcon.multisig => Icon(Icons.groups_outlined, size: 14, color: accent),
    };
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isUnderWay ? accent.useOpacity(0.08) : null,
        borderRadius: context.radiusV3.xsBorder,
        border: Border.all(color: isUnderWay ? accent.useOpacity(0.15) : colors.borderHairline, width: 1.5),
      ),
      child: Center(child: glyph),
    );
  }

  TextStyle _timeStyle(AppColorsV3 colors) =>
      context.themeTextV3.caption.copyWith(color: colors.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);

  Widget _label(AppColorsV3 colors) =>
      Text(_row.label, style: context.themeTextV3.bodyEmphasis.copyWith(color: _accent(colors)));

  Widget _amount(AppColorsV3 colors) {
    final text = context.themeTextV3.amountRow.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    if (_row.hidesAmount) return Text('—', style: text.copyWith(color: colors.textMuted));
    if (_row.movedNothing) return Text(widget.amountText, style: text.copyWith(color: colors.textMuted));
    return Text(
      '${_row.isSend ? '-' : '+'}${widget.amountText}',
      // What arrives is in sage, settled or not.
      style: text.copyWith(color: _row.isSend ? _accent(colors) : colors.semanticSage),
    );
  }

  /// Who was on the other side: one of the wallet's own accounts by its
  /// badge and name, one without an address in words, anyone else by the
  /// whole address over its checkphrase.
  Widget _who(AppColorsV3 colors) {
    if (widget.ownCounterparty case final own?) return AccountLabel(account: own);
    return switch (_row.counterparty) {
      ActivityAccount(:final address) ||
      ActivityMultisig(:final address) => DesktopAddressCheckphrase(address: address, isCompact: true),
      final ActivityUnnamedCounterparty unnamed => Text(
        unnamed.name(widget.l10n),
        style: context.themeTextV3.body.copyWith(color: colors.textContent),
      ),
    };
  }

  Widget _prefix(TextStyle style, double width) => SizedBox(
    width: width,
    child: Text(_row.counterparty.prefix(widget.l10n), style: style),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final backing = widget.isSelected
        ? colors.textContent.useOpacity(widget.hasFocus ? 0.1 : 0.05)
        : _isHovered
        ? colors.textContent.useOpacity(0.05)
        : null;
    final decoration = BoxDecoration(color: backing, borderRadius: context.radiusV3.smBorder);

    final Widget row = switch (widget.form) {
      // As tall as an address over its checkphrase needs, 56 at the least.
      ActivityRowForm.wide => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: decoration,
        child: Row(
          children: [
            _icon(colors),
            const SizedBox(width: 12),
            SizedBox(
              width: ActivityRowView._whatWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(colors),
                  const SizedBox(height: 4),
                  Text(_row.timeLabel, style: _timeStyle(colors)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  _prefix(text.body.copyWith(color: colors.textMuted), ActivityRowView._prefixWidth),
                  Flexible(child: _who(colors)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _amount(colors),
          ],
        ),
      ),
      ActivityRowForm.tight => Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: decoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _icon(colors),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        Flexible(child: _label(colors)),
                        const SizedBox(width: 8),
                        Text(_row.timeLabel, style: _timeStyle(colors)),
                        const Spacer(),
                        _amount(colors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _prefix(text.caption.copyWith(color: colors.textMuted), ActivityRowView._tightPrefixWidth),
                      Flexible(child: _who(colors)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ActivityRowForm.brief => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: decoration,
        child: Row(
          children: [
            _icon(colors),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(colors),
                  const SizedBox(height: 4),
                  Text(_row.timeLabel, style: _timeStyle(colors)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _amount(colors),
          ],
        ),
      ),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: row),
    );
  }
}
