import 'package:url_launcher/url_launcher.dart';

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
