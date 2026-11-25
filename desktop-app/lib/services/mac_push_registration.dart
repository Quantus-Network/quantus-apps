import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/providers/notification_click_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/mac_push.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/wallet_session.dart';

/// The push notification service the desktop registers with.
final senotiClientProvider = Provider<SenotiAuthClient>((ref) => SenotiAuthClient(AppConstants.senotiEndpoint));

/// Registers this Mac with the push service, which then has Apple show what
/// the wallet's accounts receive while the app is closed.
///
/// Only while the person wants notifications and macOS allows them, and only
/// from a build signed to receive pushes: any other registers nothing, as
/// Windows and Linux do. A reset removes the Mac whatever they are set to.
///
/// What is asked of the push service is sent one request at a time, in the
/// order asked, whoever asks: a reset's removal goes after a registration
/// already sent, never before it.
class MacPushRegistration implements PushRegistration {
  MacPushRegistration(this._ref);

  /// What the push service calls a Mac.
  static const platform = 'macos';

  final Ref _ref;

  /// Where it is kept, across launches, whether the push service may hold
  /// this Mac: set once a registration went through, cleared once a removal
  /// did. A reset clears it with the rest of the wallet's preferences.
  static const registeredKey = 'desktop_mac_push_registered';

  /// Ends when the last request asked for is done, however it ended.
  Future<void> _requests = Future.value();

  /// The token and addresses the push service last took this Mac's
  /// registration with, in this run; null while it holds none from this run.
  /// A removal that went through, a reset's included, clears it.
  String? _registeredFor;

  /// Runs [request] once every request asked before it is done.
  Future<T> _inTurn<T>(Future<T> Function() request) {
    final turn = _requests.then((_) => request());
    _requests = turn.then((_) {}, onError: (_) {});
    return turn;
  }

  /// Whether the push service may hold this Mac: it was registered, in this
  /// run or an earlier one, and not removed since.
  bool get mayBeRegistered => _ref.read(settingsServiceProvider).getBool(registeredKey) ?? false;

  Future<void> _keepRegistered(bool registered) =>
      _ref.read(settingsServiceProvider).setBool(registeredKey, registered);

  /// Whether the person wants notifications, macOS allows them, and remote
  /// notifications are on for everyone.
  bool get isWanted =>
      _ref.read(notificationConfigProvider).enabled &&
      _ref.read(desktopLocalNotificationsProvider) is NotificationsAllowed &&
      _ref.read(remoteConfigProvider).enableRemoteNotifications;

  /// The addresses the push service may be told of, once the wallet's
  /// accounts are known: never an Encrypted account's.
  List<String>? get notifiableAddresses {
    final accounts = _ref.read(accountsProvider).value;
    final multisigs = _ref.read(multisigAccountsProvider).value;
    if (accounts == null || multisigs == null) return null;
    return SenotiService.notifiableAddresses(accounts, multisigs);
  }

  /// Registers the Mac for every address that may be told of. Before the
  /// accounts are known there is nothing to register: [MacPushSync] does it
  /// when they are.
  ///
  /// Asked for the wallet there is now: if a reset wipes it meanwhile,
  /// nothing is registered. The addresses are read last, just before they
  /// are sent.
  @override
  Future<void> registerDevice() => register();

  /// As [registerDevice]: true once the push service holds the registration
  /// for the addresses there are now, as it already did or does from this
  /// request; false when nothing was sent. Throws when it failed.
  Future<bool> register() {
    final session = _ref.read(walletSessionProvider);
    final ticket = session.ticket;
    return _inTurn(() async {
      if (!await _stillThisWallet(session, ticket)) return false;
      if (!isWanted) return false;
      if (notifiableAddresses?.isEmpty ?? true) return false;
      final push = _ref.read(macPushProvider);
      final environment = await push.environment();
      if (environment == null) {
        _notSignedForPushes();
        return false;
      }
      final token = await push.requestToken();
      // Asked again after waiting for Apple: the person may have switched
      // notifications off meanwhile.
      if (!await _stillThisWallet(session, ticket) || !isWanted) return false;
      final addresses = notifiableAddresses;
      if (addresses == null || addresses.isEmpty) return false;
      final registration = _keyOf(token, addresses);
      if (registration == _registeredFor) return true;
      await _ref
          .read(senotiClientProvider)
          .registerDevice(addresses: addresses, deviceToken: token, platform: platform, apnsEnvironment: environment);
      _registeredFor = registration;
      await _keepRegistered(true);
      return true;
    });
  }

  /// Waits out a reset under way: false once it wiped the wallet [ticket]
  /// was taken for, true if that wallet is still here.
  Future<bool> _stillThisWallet(WalletSession session, int ticket) =>
      session.survivesReset(ticket, dropping: "registering this Mac for a wiped wallet's addresses");

  /// Nothing to do here: [MacPushSync] registers the wallet's addresses
  /// whenever its accounts change, so that no account flow waits for Apple
  /// to answer with this Mac's token.
  @override
  Future<void> registerAddress(String address) async {}

  /// A reset does not wait for this and cannot be failed by it, so a failure
  /// is reported here.
  @override
  Future<void> unregister() => remove();

  /// As [unregister]: true once the push service holds this Mac no more,
  /// false when the removal failed, which is reported.
  Future<bool> remove() => _inTurn(_remove);

  /// Removes the Mac if the push service may hold it, as it stands once every
  /// request asked before is done: a registration still on its way when the
  /// person switched notifications off is removed after it. True once the
  /// push service holds it no more.
  Future<bool> removeIfHeld() => _inTurn(() async => !mayBeRegistered || await _remove());

  Future<bool> _remove() async {
    try {
      final push = _ref.read(macPushProvider);
      if (await push.environment() == null) {
        // Such a build was never registered: there is nothing to remove.
        _notSignedForPushes();
        return true;
      }
      await _ref.read(senotiClientProvider).unregisterDevice(deviceToken: await push.requestToken());
      _registeredFor = null;
      await _keepRegistered(false);
      return true;
    } catch (e) {
      quantusPrint('Removing this Mac from the push service failed: $e');
      _ref.read(telemetryProvider).sendError('desktop_push_unregister_failed', error: e);
      return false;
    }
  }

  static String _keyOf(String token, List<String> addresses) => [token, ...addresses].join('\n');

  void _notSignedForPushes() => quantusPrint('This build was not signed to receive pushes: nothing to register');
}

final macPushRegistrationProvider = Provider<MacPushRegistration>(MacPushRegistration.new);

/// Keeps this Mac's registration as the person's choices and the wallet's
/// accounts are: registered while notifications are wanted and allowed, for
/// the accounts the wallet has now, and removed once they are switched off.
/// Clicks on what was pushed open what it was about.
class MacPushSync {
  MacPushSync(this._ref) {
    _ref.listen(desktopLocalNotificationsProvider, (_, _) => _changed());
    _ref.listen(notificationConfigProvider.select((config) => config.enabled), (_, _) => _changed());
    _ref.listen(remoteConfigProvider.select((config) => config.enableRemoteNotifications), (_, _) => _changed());
    _ref.listen(accountsProvider, (_, _) => _changed());
    _ref.listen(multisigAccountsProvider, (_, _) => _changed());
    unawaited(_listenToClicks());
    _changed();
  }

  final Ref _ref;

  /// Whether a look at what changed is already waiting its turn.
  var _isQueued = false;
  Future<void> _turn = Future.value();

  Future<void> _listenToClicks() async {
    try {
      await _ref.read(macPushProvider).listenToClicks((payload) => _ref.read(notificationClickProvider).open(payload));
    } catch (e) {
      quantusPrint('Listening for clicks on pushed notifications failed: $e');
      if (_ref.mounted) _ref.read(telemetryProvider).sendError('desktop_push_clicks_unavailable', error: e);
    }
  }

  /// One registration or removal at a time, each for the state it finds.
  void _changed() {
    if (_isQueued) return;
    _isQueued = true;
    _turn = _turn.then((_) {
      _isQueued = false;
      return _reconcile();
    });
  }

  /// Brings the push service to what is wanted now. [MacPushRegistration]
  /// knows what it holds, and changes that only once it said so: a change
  /// that failed is tried again at the next change looked at, or at the next
  /// launch.
  Future<void> _reconcile() async {
    if (!_ref.mounted) return;
    final registration = _ref.read(macPushRegistrationProvider);
    if (!registration.isWanted) {
      await registration.removeIfHeld();
      return;
    }
    try {
      await registration.register();
    } catch (e) {
      quantusPrint('Registering this Mac with the push service failed: $e');
      if (_ref.mounted) _ref.read(telemetryProvider).sendError('desktop_push_register_failed', error: e);
    }
  }
}

/// Started with the app, on a Mac: Windows and Linux have no push service
/// that reaches a closed app.
final macPushSyncProvider = Provider<MacPushSync?>(
  (ref) => defaultTargetPlatform == TargetPlatform.macOS ? MacPushSync(ref) : null,
);
