import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_desktop_wallet/providers/balance_providers.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Sidebar plus the selected tab. Hosts the keyboard shortcuts for switching
/// tabs: Cmd on macOS, Ctrl elsewhere.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const AppShell({super.key, required this.shell});

  static bool get usesCommandKey => Platform.isMacOS;

  static String shortcutLabel(int index) => '${usesCommandKey ? '⌘' : 'Ctrl+'}${index + 1}';

  void _select(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(balanceRefreshTickerProvider);
    final keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ];
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < keys.length; i++)
          SingleActivator(keys[i], meta: usesCommandKey, control: !usesCommandKey): () => _select(i),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: context.colorsV3.bgVoid,
          body: Row(
            children: [
              Sidebar(currentIndex: shell.currentIndex, onSelect: _select),
              Expanded(child: shell),
            ],
          ),
        ),
      ),
    );
  }
}
