import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:share_plus/share_plus.dart';

String buildAccountShareText(String accountId) => accountId;

void shareAccountDetails(BuildContext context, String accountId) =>
    shareText(context, buildAccountShareText(accountId), subject: 'Shared Address');

void shareText(BuildContext context, String text, {String? subject}) {
  SharePlus.instance.share(
    ShareParams(text: text, subject: subject, title: subject, sharePositionOrigin: context.sharePositionRect()),
  );
}
