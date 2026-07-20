import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/bootstrap/app_bootstrap.dart';

void main() async {
  await bootstrap();
  // buildApp() wraps the tree in a ProviderScope; the lint can't see through it.
  // ignore: riverpod_lint/missing_provider_scope
  runApp(buildApp());
}
