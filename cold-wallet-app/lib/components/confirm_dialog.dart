import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) {
  return showQuantusDialog(context, title: title, body: message, actionLabel: confirmLabel);
}
