import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class BottomSheetContainer extends StatelessWidget {
  final String title;
  final Widget Function(String title)? titleBuilder;
  final Widget child;
  final VoidCallback? onBack;
  final double? height;
  final bool showDragHandle;

  const BottomSheetContainer({
    super.key,
    required this.title,
    required this.child,
    this.titleBuilder,
    this.onBack,
    this.height,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final topPadding = showDragHandle ? 12.0 : 40.0;
    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.borderButton, width: 1),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDragHandle) ...[
            Center(
              child: Container(
                width: 56,
                height: 4,
                decoration: BoxDecoration(color: colors.borderButton, borderRadius: BorderRadius.circular(23)),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onBack != null)
                GestureDetector(
                  onTap: onBack,
                  child: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
                ),

              if (titleBuilder != null)
                titleBuilder!(title)
              else
                Text(
                  title,
                  style: text.smallTitle?.copyWith(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: colors.textPrimary, size: 20),
              ),
            ],
          ),
          SizedBox(height: showDragHandle ? 28 : 32),
          if (height != null) Expanded(child: child) else Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }

  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, RouteSettings? routeSettings}) {
    return showModalBottomSheet<T>(
      context: context,
      routeSettings: routeSettings,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), child: builder(ctx)),
    );
  }
}
