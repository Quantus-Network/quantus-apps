import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// A sheet over the window: its title and a way out. Each feature fills in
/// its own sheet as it arrives.
class ShellSheetView extends ConsumerWidget {
  const ShellSheetView({super.key, required this.sheet});

  final ShellSheet sheet;

  static const double _width = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;

    return Dialog(
      backgroundColor: colors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: context.radiusV3.mdBorder,
        side: BorderSide(color: colors.borderHairline),
      ),
      child: SizedBox(
        width: _width,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sheetTitle(l10n, sheet), style: context.themeTextV3.titleScreen.copyWith(color: colors.textContent)),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: QuantusButton.simple(
                  label: l10n.commonClose,
                  width: null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  variant: ButtonVariant.staged,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
