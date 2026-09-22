import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:share_plus/share_plus.dart';

String buildAccountShareText(String accountId, {required String checksum}) {
  return accountId;
}

void shareAccountDetails(BuildContext context, String accountId, {required String checksum}) =>
    shareText(context, buildAccountShareText(accountId, checksum: checksum), subject: 'Shared Address');

void shareText(BuildContext context, String text, {String? subject}) {
  SharePlus.instance.share(
    ShareParams(text: text, subject: subject, title: subject, sharePositionOrigin: context.sharePositionRect()),
  );
}
