import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shared v3 sheet shell: handle, title, content slot.
///
/// Presentational only. Overlay presentation is [BottomSheetContainer.show].
class BottomSheetContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;

  const BottomSheetContainer({super.key, required this.title, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.lgBorder),
      child: Column(
        mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.headingRow.copyWith(color: colors.textContent)),
          const SizedBox(height: 16),
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
      enableDrag: true,
      isDismissible: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: builder(ctx),
            ),
          ),
        );
      },
    );
  }
}
