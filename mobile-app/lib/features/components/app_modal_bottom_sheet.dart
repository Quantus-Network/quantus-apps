import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

Future<T?> showAppModalBottomSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.green,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: builder(context)),
  );
}
