import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/receive/receive_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// A sheet over the window, hanging from under the header as a macOS sheet
/// hangs from the title bar: a title row with a way out, then the sheet's
/// own content. A sheet that acts on the active account names it in the
/// title row. Each feature fills in its own sheet as it arrives.
class ShellSheetView extends ConsumerWidget {
  const ShellSheetView({super.key, required this.sheet});

  final ShellSheet sheet;

  /// How wide a sheet grows, when the pane leaves room.
  static const double maxWidth = 700;

  bool get _actsOnAccount => switch (sheet) {
    ShellSheet.receive || ShellSheet.send || ShellSheet.propose || ShellSheet.swap => true,
    ShellSheet.addAccount || ShellSheet.settings => false,
  };

  Widget? get _content => switch (sheet) {
    ShellSheet.receive => const ReceiveSheet(),
    ShellSheet.send || ShellSheet.propose || ShellSheet.swap || ShellSheet.addAccount || ShellSheet.settings => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = _actsOnAccount ? ref.watch(activeAccountProvider).value?.account : null;
    final content = _content;
    final radius = Radius.circular(context.radiusV3.lg);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: radius),
        boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.6), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: Material(
        color: colors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: radius),
          side: BorderSide(color: colors.borderHairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(sheetTitle(l10n, sheet), style: text.titleScreen.copyWith(color: colors.textContent)),
                  if (account != null) ...[
                    const SizedBox(width: 14),
                    DesktopAccountBadge(account: account, size: 22),
                    const SizedBox(width: 8),
                    // Takes the rest of the row, so the close button keeps to the end.
                    Expanded(
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                        style: text.body.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark, size: 15),
                    color: colors.textMuted,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (content != null) ...[const SizedBox(height: 18), content],
            ],
          ),
        ),
      ),
    );
  }
}
