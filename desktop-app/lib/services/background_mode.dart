import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/swaps_in_progress_provider.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/services/background_window.dart';
import 'package:quantus_desktop_wallet/services/notification_delivery.dart';
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

/// Whether anything keeps the app running with its window closed: work under
/// way ([pendingWorkProvider]), or a swap in progress, so that how it ends is
/// told. A swap goes on whether the app runs or not, so quitting does not wait
/// for one, and one that runs long is not taken for work that is stuck.
final keepsRunningProvider = Provider<bool>(
  (ref) => ref.watch(pendingWorkProvider) || ref.watch(swapsInProgressProvider.select((swaps) => swaps.isNotEmpty)),
);

/// Keeps the app running with its window closed while something is under
/// way ([keepsRunningProvider]), where the platform can
/// ([supportsBackgroundMode]). Otherwise closing the window quits the app.
class BackgroundMode {
  /// How long the app stays once its last work has settled.
  static const settleDelay = NotificationDelivery.settleDelay;

  /// How long the window stays closed with work that has not settled. A chain
  /// call has no timeout of its own, so one that hangs would otherwise leave
  /// the app running out of sight for good. A swap has its own end: it is
  /// polled no more once it is overdue.
  static const hiddenLimit = Duration(minutes: 30);

  BackgroundMode(this._ref) : _window = _ref.read(backgroundWindowProvider), _telemetry = _ref.read(telemetryProvider) {
    if (!supportsBackgroundMode) return;
    _window.listen(onWillClose: _onCloseButton, onDidOpen: _markOpen);
    final quitRequests = AppLifecycleListener(onExitRequested: _onQuitRequested);
    _ref.onDispose(() {
      quitRequests.dispose();
      _window.stopListening();
      _hiddenLimitTimer?.cancel();
      _quitTimer?.cancel();
    });
    _ref.listen<StatusItemLabels>(
      statusItemLabelsProvider,
      (_, labels) => unawaited(_reported(_window.configure(labels))),
      fireImmediately: true,
    );
    _ref.listen<bool>(keepsRunningProvider, (_, isRunning) {
      unawaited(_reported(_window.setStayAwake(isRunning)));
      if (!isRunning) _quitOnceSettled();
    });
    // A swap followed from the last run may be in progress from the start.
    if (_ref.read(keepsRunningProvider)) unawaited(_reported(_window.setStayAwake(true)));
    // A menu still works with the window closed, and what it opens must show.
    _ref.listen<ShellSheet?>(shellSheetProvider, (_, sheet) {
      if (sheet != null && _ref.read(windowClosedProvider)) unawaited(_reported(_window.bringToFront()));
    });
  }

  final Ref _ref;
  final BackgroundWindow _window;
  final Telemetry _telemetry;

  /// Runs from the window closing until it is back, for [hiddenLimit].
  Timer? _hiddenLimitTimer;

  /// Runs for [settleDelay] once the work has settled and been reported.
  Timer? _quitTimer;

  WindowClosedNotifier get _closed => _ref.read(windowClosedProvider.notifier);

  /// Whether quitting now would cut work short or lose what it has to say.
  /// Every way of quitting asks this, but Quit Now.
  bool get _mustStay => _ref.read(pendingWorkProvider) || _ref.read(notificationDeliveryProvider).isSettling;

  /// Whether closing the window is to leave the app running: what quitting
  /// asks about, or a swap in progress.
  bool get _staysOnClose => _mustStay || _ref.read(keepsRunningProvider);

  /// File › Close Window: hides the window while work is under way, and
  /// otherwise asks the app to quit.
  Future<void> closeWindow() async {
    if (!supportsBackgroundMode || !_staysOnClose) {
      _ref.read(requestAppExitProvider)();
      return;
    }
    await _getReadyToClose();
    try {
      await _window.hide();
    } catch (e) {
      _report(e);
      _markOpen();
    }
  }

  /// Finishes what is under way out of sight, then quits: the answer to the
  /// question of [quitQuestionProvider].
  Future<void> finishThenQuit() {
    _ref.read(quitQuestionProvider.notifier).set(false);
    return closeWindow();
  }

  /// Quits at once, whatever is under way: the other answer.
  void quitNow() {
    _ref.read(quitQuestionProvider.notifier).set(false);
    _ref.read(forceAppExitProvider)();
  }

  /// Cmd+Q, the menu bar icon's Quit, or anything else asking the app to quit.
  /// With work under way the answer is no, at once, and the person is asked:
  /// while an answer is outstanding the engine takes another request to quit
  /// as settled, and would quit with no question.
  Future<AppExitResponse> _onQuitRequested() async {
    if (!_mustStay) return AppExitResponse.exit;
    // Also when already asking: the window may have been closed behind it.
    if (_ref.read(windowClosedProvider)) unawaited(_reported(_window.bringToFront()));
    _ref.read(quitQuestionProvider.notifier).set(true);
    return AppExitResponse.cancel;
  }

  /// The close button: whether the window is to hide, decided now so that
  /// work started a moment ago counts. If not, it closes, which quits the app.
  Future<bool> _onCloseButton() async {
    if (!_staysOnClose) return false;
    await _getReadyToClose();
    return true;
  }

  /// Says the window is closing, and waits for a frame without what must not
  /// be there when it comes back: the window shows its last frame on return.
  Future<void> _getReadyToClose() async {
    _closed.set(true);
    _hiddenLimitTimer?.cancel();
    _hiddenLimitTimer = Timer(hiddenLimit, _onHiddenTooLong);
    // Only a notification's last moment is left: no more work will settle.
    if (!_ref.read(keepsRunningProvider)) _quitOnceSettled();
    final scheduler = SchedulerBinding.instance;
    if (scheduler.framesEnabled) await scheduler.endOfFrame;
  }

  /// The window is back, or never left: nothing is to quit the app any more.
  void _markOpen() {
    _hiddenLimitTimer?.cancel();
    _hiddenLimitTimer = null;
    _quitTimer?.cancel();
    _quitTimer = null;
    _closed.set(false);
  }

  /// With the window closed, quits a moment after the work has settled,
  /// unless more has started by then.
  void _quitOnceSettled() {
    _quitTimer?.cancel();
    if (!_ref.read(windowClosedProvider)) return;
    _quitTimer = Timer(settleDelay, () {
      if (_ref.read(keepsRunningProvider)) return;
      if (_ref.read(notificationDeliveryProvider).isSettling) {
        _quitOnceSettled();
        return;
      }
      _ref.read(requestAppExitProvider)();
    });
  }

  /// Something has not settled for so long that it may never: the window comes
  /// back, for the person to see and decide. Nothing is stopped. A swap still
  /// in progress is not stuck: it ends, or turns overdue, on its own.
  void _onHiddenTooLong() {
    if (!_mustStay) return;
    final error = StateError('Work was still under way ${hiddenLimit.inMinutes} minutes after the window closed');
    quantusPrint('$error');
    _telemetry.sendError('desktop_background_work_stuck', error: error);
    unawaited(_reported(_window.bringToFront()));
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
