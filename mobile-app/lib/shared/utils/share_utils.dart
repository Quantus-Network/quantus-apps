import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:share_plus/share_plus.dart';

String buildAccountShareText(String accountId, {required String checksum}) {
  return accountId;
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
