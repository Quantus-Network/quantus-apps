import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String urlString, {LaunchMode mode = LaunchMode.platformDefault}) async {
  final uri = Uri.parse(urlString);
  try {
    final launched = await launchUrl(uri, mode: mode);
    if (!launched) {
      quantusDebugPrint('launchUrl returned false: $urlString');
    }
  } catch (e, st) {
    quantusDebugPrint('launchUrl failed: $urlString error=$e\n$st');
  }
}
