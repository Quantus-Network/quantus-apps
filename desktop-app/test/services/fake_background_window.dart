import 'dart:ui';

import 'package:quantus_desktop_wallet/services/background_window.dart';

/// Stands in for the native window: records what the app asks of it, and
/// lets a test press its close button or bring it back.
class FakeBackgroundWindow implements BackgroundWindow {
  /// Each thing the window was told, in order.
  final configured = <StatusItemLabels>[];

  /// `hide`, `quit` (the close button let through) and `bringToFront`, in
  /// the order they happened.
  final calls = <String>[];

  /// Each request to stay awake (true) or that it is no longer needed (false).
  final stayAwake = <bool>[];

  /// When set, configuring the window fails with this.
  Object? configureError;

  /// When set, hiding the window fails with this.
  Object? hideError;

  Future<bool> Function()? _onWillClose;
  VoidCallback? _onDidOpen;

  @override
  Future<void> configure(StatusItemLabels labels) async {
    if (configureError case final error?) throw error;
    configured.add(labels);
  }

  @override
  Future<void> hide() async {
    if (hideError case final error?) throw error;
    calls.add('hide');
  }

  @override
  Future<void> setStayAwake(bool isAwake) async => stayAwake.add(isAwake);

  @override
  Future<void> bringToFront() async {
    calls.add('bringToFront');
    _onDidOpen?.call();
  }

  @override
  void listen({required Future<bool> Function() onWillClose, required VoidCallback onDidOpen}) {
    _onWillClose = onWillClose;
    _onDidOpen = onDidOpen;
  }

  @override
  void stopListening() {
    _onWillClose = null;
    _onDidOpen = null;
  }

  /// The window's close button: the app says whether to hide the window, and
  /// otherwise it closes, which quits the app.
  Future<void> pressCloseButton() async => calls.add(await _onWillClose!() ? 'hide' : 'quit');

  /// The Dock icon or the menu bar icon brought the window back.
  void reopen() => _onDidOpen!();
}
