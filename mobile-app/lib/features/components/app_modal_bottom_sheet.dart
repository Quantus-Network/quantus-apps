import 'dart:ui';
import 'package:flutter/material.dart';

Future<T?> showAppModalBottomSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext modalContext) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0.37, -0.01),
                    end: const Alignment(0.37, 1.00),
                    colors: [Colors.black.withOpacity(0.7), const Color(0xFF322F6E).withOpacity(0.7)],
                  ),
                ),
              ),
            ),
            builder(modalContext),
          ],
        ),
      );
    },
  );
}
