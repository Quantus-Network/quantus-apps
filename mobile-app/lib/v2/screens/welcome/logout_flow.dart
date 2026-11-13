import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/logout_service.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';

/// Logs the wallet out and replaces every route with the welcome screen.
Future<void> logoutAndReturnToWelcome(BuildContext context, WidgetRef ref) async {
  await ref.read(logoutServiceProvider).logout();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreenV2()), (r) => false);
}
