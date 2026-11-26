import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

// What the pages of the panel at the window's right are made of, whatever
// they show: a transaction, a proposal, the swap.

/// A small label in capitals, as Send's receipt heads its blocks.
TextStyle inspectorCapsStyle(BuildContext context, {Color? color}) => context.themeTextV3.dataAddress.copyWith(
  height: 1,
  letterSpacing: 2.4,
  color: color ?? context.colorsV3.textMuted2,
);

/// What a page leads with: an amount, a dash for none, or what stands for one.
Widget inspectorHeadline(BuildContext context, String text, {Color? color}) => Text(
  text,
  style: context.themeTextV3.titleHero.copyWith(
    fontSize: 26,
    height: 1.05,
    letterSpacing: -0.65,
    color: color ?? context.colorsV3.textWhite,
  ),
);

/// A line of the status: its mark, its word in capitals, and what follows.
Widget inspectorStatusLine(
  BuildContext context, {
  Widget? mark,
  required String label,
  required Color color,
  String? after,
}) {
  final caps = inspectorCapsStyle(context, color: color);
  return SizedBox(
    height: 14,
    child: Row(
      children: [
        if (mark != null) ...[mark, const SizedBox(width: 8)],
        CapsText(label, style: caps),
        if (after != null) ...[
          const SizedBox(width: 12),
          Text(
            after,
            style: context.themeTextV3.body.copyWith(
              color: context.colorsV3.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    ),
  );
}

/// A row's label, quiet.
Widget inspectorLabel(BuildContext context, String text) =>
    Text(text, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted));

/// Who: one of the wallet's own accounts by its badge and name, else the
/// whole address over its checkphrase.
Widget inspectorAccount(BaseAccount? own, String address) => own == null
    ? DesktopAddressCheckphrase(address: address, isCompact: true)
    : AccountLabel(account: own, revealsAddress: true);

/// An account under its [label]: one of the wallet's own by its badge and
/// name at the line's end; any other by its whole address, too long to share
/// the line, under the label.
Widget inspectorAccountRow(BuildContext context, String label, BaseAccount? own, String address) {
  if (own != null) {
    return SummaryRow(
      label: inspectorLabel(context, label),
      value: AccountLabel(account: own, revealsAddress: true),
    );
  }
  return Padding(
    padding: SummaryRow.padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorLabel(context, label),
        const SizedBox(height: 6),
        DesktopAddressCheckphrase(address: address, isCompact: true),
      ],
    ),
  );
}

/// View in Explorer, and, where the system has a share picker, Share: both
/// for [page], unavailable while there is none.
class InspectorPageActions extends ConsumerWidget {
  const InspectorPageActions({super.key, required this.page});

  final String? page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final page = this.page;
    return ToolbarActionRow(
      edge: ToolbarActionEdge.leading,
      wraps: true,
      children: [
        ToolbarAction.symbol(
          symbol: CupertinoIcons.arrow_up_right_square,
          label: l10n.desktopViewInExplorer,
          onPressed: page == null ? null : () => unawaited(ref.read(openExternalUrlProvider)(Uri.parse(page))),
        ),
        // Only macOS has a share picker to hand the page to.
        if (defaultTargetPlatform == TargetPlatform.macOS)
          Builder(
            builder: (button) => ToolbarAction.symbol(
              symbol: CupertinoIcons.square_arrow_up,
              label: l10n.componentShare,
              onPressed: page == null
                  ? null
                  : () => unawaited(ref.read(shareTextProvider)(page, origin: button.sharePositionRect())),
            ),
          ),
      ],
    );
  }
}
