import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class BottomSheetContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const BottomSheetContainer({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF3D3D3D)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: colors.textPrimary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    );
  }

  static void show(BuildContext context, {required WidgetBuilder builder}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), child: builder(ctx)),
    );
  }
}
