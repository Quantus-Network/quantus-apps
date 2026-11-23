import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/services/background_window.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/services/telemetry.dart';

/// What the menu bar icon's items say, in the app's language.
final statusItemLabelsProvider = Provider<StatusItemLabels>((ref) {
  final l10n = ref.watch(l10nProvider);
  return (openLabel: l10n.desktopStatusItemOpen(appTitle), quitLabel: l10n.desktopStatusItemQuit(appTitle));
});

/// Whether something is under way that quitting would cut short or leave
/// unreported: a send or a multisig action being watched for on the chain, or
/// one still being approved, signed or proved ([workHoldsProvider]).
final pendingWorkProvider = Provider<bool>(
  (ref) =>
      ref.watch(pendingTransactionsProvider).isNotEmpty ||
      ref.watch(pendingMultisigProposalsProvider).isNotEmpty ||
      ref.watch(pendingMultisigApprovalsProvider).isNotEmpty ||
      ref.watch(pendingMultisigExecutionsProvider).isNotEmpty ||
      ref.watch(pendingMultisigCancellationsProvider).isNotEmpty ||
      ref.watch(pendingMultisigCreationsProvider).isNotEmpty ||
      ref.watch(workHoldsProvider).isNotEmpty,
);

/// Keeps the app running with its window closed while work is under way
/// ([pendingWorkProvider]), where the platform can ([supportsBackgroundMode]).
/// Otherwise closing the window quits the app.
class BackgroundMode {
  BackgroundMode(this._ref) : _window = _ref.read(backgroundWindowProvider), _telemetry = _ref.read(telemetryProvider) {
    if (!supportsBackgroundMode) return;
    _window.listen(onWillClose: _onCloseButton, onDidOpen: () => _closed.set(false));
    _ref.onDispose(_window.stopListening);
    _ref.listen<StatusItemLabels>(
      statusItemLabelsProvider,
      (_, labels) => unawaited(_reported(_window.configure(labels))),
      fireImmediately: true,
    );
    _ref.listen<bool>(pendingWorkProvider, (_, isPending) => unawaited(_reported(_window.setStayAwake(isPending))));
    // A menu still works with the window closed, and what it opens must show.
    _ref.listen<ShellSheet?>(shellSheetProvider, (_, sheet) {
      if (sheet != null && _ref.read(windowClosedProvider)) unawaited(_reported(_window.bringToFront()));
    });
  }

  final Ref _ref;
  final BackgroundWindow _window;
  final Telemetry _telemetry;

  WindowClosedNotifier get _closed => _ref.read(windowClosedProvider.notifier);

  /// File › Close Window: hides the window while work is under way, and
  /// otherwise asks the app to quit.
  Future<void> closeWindow() async {
    if (!supportsBackgroundMode || !_ref.read(pendingWorkProvider)) {
      _ref.read(requestAppExitProvider)();
      return;
    }
    await _getReadyToClose();
    try {
      await _window.hide();
    } catch (e) {
      _report(e);
      _closed.set(false);
    }
  }

  /// The close button: whether the window is to hide, decided now so that
  /// work started a moment ago counts. If not, it closes, which quits the app.
  Future<bool> _onCloseButton() async {
    if (!_ref.read(pendingWorkProvider)) return false;
    await _getReadyToClose();
    return true;
  }

  /// Says the window is closing, and waits for a frame without what must not
  /// be there when it comes back: the window shows its last frame on return.
  Future<void> _getReadyToClose() async {
    _closed.set(true);
    final scheduler = SchedulerBinding.instance;
    if (scheduler.framesEnabled) await scheduler.endOfFrame;
  }

  Future<void> _reported(Future<void> request) async {
    try {
      await request;
    } catch (e) {
      _report(e);
    }
  }

  void _report(Object error) {
    quantusPrint('A request of the window for running in the background failed: $error');
    _telemetry.sendError('desktop_background_mode_failed', error: error);
  }
}

final backgroundModeProvider = Provider<BackgroundMode>(BackgroundMode.new);
