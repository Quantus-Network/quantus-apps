import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';

void main() async {
  await bootstrap();
  // buildApp() wraps the tree in a ProviderScope; the lint can't see through it.
  // ignore: riverpod_lint/missing_provider_scope
  runApp(buildApp());
}
