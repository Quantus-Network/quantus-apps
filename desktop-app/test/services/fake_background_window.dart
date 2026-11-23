import 'dart:ui';

import 'package:quantus_desktop_wallet/services/background_window.dart';

/// Stands in for the native window: records what the app asks of it, and
/// lets a test press its close button or bring it back.
class FakeBackgroundWindow implements BackgroundWindow {
  /// Each thing the window was told, in order.
  final configured = <BackgroundModeRequest>[];

  /// `hide` and `bringToFront`, in the order asked.
  final calls = <String>[];

  /// When set, configuring the window fails with this.
  Object? configureError;

  /// When set, hiding the window fails with this.
  Object? hideError;

  Future<void> Function()? _onWillClose;
  VoidCallback? _onDidOpen;

  @override
  Future<void> configure(BackgroundModeRequest request) async {
    if (configureError case final error?) throw error;
    configured.add(request);
  }

  @override
  Future<void> hide() async {
    if (hideError case final error?) throw error;
    calls.add('hide');
  }

  @override
  Future<void> bringToFront() async {
    calls.add('bringToFront');
    _onDidOpen?.call();
  }

  @override
  void listen({required Future<void> Function() onWillClose, required VoidCallback onDidOpen}) {
    _onWillClose = onWillClose;
    _onDidOpen = onDidOpen;
  }

  @override
  void stopListening() {
    _onWillClose = null;
    _onDidOpen = null;
  }

  /// The window's close button: the app is told, then the window leaves.
  Future<void> pressCloseButton() => _onWillClose!();

  /// The Dock icon or the menu bar icon brought the window back.
  void reopen() => _onDidOpen!();
}
