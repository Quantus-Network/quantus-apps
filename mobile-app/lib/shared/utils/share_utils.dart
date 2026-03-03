import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:share_plus/share_plus.dart';

String buildAccountShareText(String accountId, {required String checksum}) {
  final checkphrasePart = '\n\nCheckphrase:$checksum';

  return 'Hey! These are my Quantus account details:\n\nAddress:\n$accountId$checkphrasePart\n\nTo open in the app or to download click the link below:\n${AppConstants.websiteBaseUrl}/account?id=$accountId';
}

void shareAccountDetails(BuildContext context, String accountId, {required String checksum}) {
  SharePlus.instance.share(
    ShareParams(
      text: buildAccountShareText(accountId, checksum: checksum),
      subject: 'Shared Address',
      title: 'Shared Address',
      sharePositionOrigin: context.sharePositionRect(),
    ),
  );
}

void shareText(BuildContext context, String text) {
  SharePlus.instance.share(ShareParams(text: text));
}
