import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String urlString, {LaunchMode mode = LaunchMode.platformDefault}) async {
  final uri = Uri.parse(urlString);
  try {
    final launched = await launchUrl(uri, mode: mode);
    if (!launched) {
      quantusPrint('launchUrl returned false: $urlString');
    }
  } catch (e, st) {
    quantusPrint('launchUrl failed: $urlString error=$e\n$st');
  }
}
