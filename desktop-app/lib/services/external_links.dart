import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app, in the system's browser.
typedef OpenExternalUrl = Future<void> Function(Uri url);

final openExternalUrlProvider = Provider<OpenExternalUrl>(
  (ref) => (url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('Nothing on this computer opened $url');
  },
);
