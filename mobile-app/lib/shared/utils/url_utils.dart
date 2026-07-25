import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

/// Block-explorer URL for an immediate (single-signer) transfer extrinsic.
String explorerImmediateTransactionUrl(String extrinsicHash) =>
    '${AppConstants.explorerEndpoint}/immediate-transactions/$extrinsicHash';

Future<void> launchXPost(String xUrl) async {
  final match = RegExp(r'/status/(\d+)').firstMatch(xUrl);
  if (match != null) {
    final native = Uri.parse('twitter://status?id=${match.group(1)}');
    if (await canLaunchUrl(native)) {
      await launchUrl(native);
      return;
    }
  }
  await launchUrl(Uri.parse(xUrl), mode: LaunchMode.externalApplication);
}
