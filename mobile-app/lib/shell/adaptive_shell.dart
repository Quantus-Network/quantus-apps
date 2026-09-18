import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/shared/utils/platform_utils.dart';
import 'package:resonance_network_wallet/shell/desktop_shell.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';

/// Renders [DesktopShell] on Linux, macOS, and Windows; [HomeScreen] on mobile.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key});

  @override
  Widget build(BuildContext context) {
    if (isDesktopPlatform) {
      return const DesktopShell();
    }
    return const HomeScreen();
  }
}
