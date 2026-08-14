import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// A titled bottom sheet that sizes to its content and scrolls once that
/// content outgrows the screen.
///
/// Disclosure that lives at the end of a long scrolling page cannot expand in
/// place: the reader is already at the bottom, so the revealed content lands
/// below the viewport and nothing appears to happen. A sheet is visible wherever
/// the page happens to be scrolled.
Future<void> showTitledSheet(BuildContext context, {required String title, required Widget child}) {
  final colors = context.colors;
  final text = context.themeText;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.sheetBackground,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    ),
  );
}
